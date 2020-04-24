class Refund < ApplicationRecord
    # ActiveRecord Callbacks

  after_initialize :initialize_refund
  
  before_create :set_line_item_refunds
  
  before_create :ensure_line_item_refunds_valid

  after_create :update_charge_for_refund_creation

  after_create :update_invoice_for_refund_creation

  after_create :process

  # ActiveRecord Associations

  belongs_to :charge

  has_one :invoice, through: :charge
  
  #has_many :notifications,
  #  as: :eventable

  # Validations

  validates :stripe_id, presence: true,
    unless: Proc.new { |rfnd| rfnd.may_lack_stripe_info? }

  validates :amount, presence: true
  
  validates :currency, presence: true,
    unless: Proc.new { |rfnd| rfnd.may_lack_stripe_info? }
  
  validates :stripe_status, presence: true,
    unless: Proc.new { |rfnd| rfnd.may_lack_stripe_info? }

  validates :status, presence: true

  # Enums

  enum status: ['processing', 'queued', 'pending', 'succeeded', 'succeeded_via_dispute_payout', 'failed', 'errored', 'failed_and_handled'] # 'failed_and_handled' exists so that we can query for failed or errored refunds and then change their status once they have been issued manually or otherwise taken care of

  enum stripe_status: ['pending', 'succeeded', 'failed', 'canceled'], _prefix: true

  enum stripe_reason: ['duplicate', 'fraudulent', 'requested_by_customer']

  # Class Methods

  def self.statuses_indicating_no_stripe_info
    ['processing', 'queued', 'succeeded_via_dispute_payout', 'errored', 'failed_and_handled'] # failed_and_handled MIGHT have stripe info, but might not
  end

  # Methods

  def must_start_queued?
    return(charge.refunds_must_start_queued?)
  end

  def may_lack_stripe_info?
    self.class.statuses_indicating_no_stripe_info.include?(status)
  end

  def apply_dispute_payout(payout_amount, should_save = true)
    return false if !['queued', 'processing'].include?(status) || payout_amount > amount - amount_returned_via_dispute
    self.amount_returned_via_dispute += payout_amount
    self.status = 'succeeded_via_dispute_payout' if amount_returned_via_dispute == amount
    return self.save if should_save
    return true
  end

  def update_from_stripe_hash(refund_hash)
    invoice.with_lock do # we lock the invoice to ensure serial processing with other invoice events
      update(
        amount: refund_hash['amount'],
        currency: refund_hash['currency'],
        failure_reason: refund_hash['failure_reason'],
        stripe_reason: refund_hash['reason'],
        receipt_number: refund_hash['receipt_number'],
        stripe_status: refund_hash['status'],
        status: status_from_stripe_status(refund_hash['status'])
      ) # most of these are not expected to be able to change, but are included for completeness
    end
  end

  def process(allow_processing_if_queued = false)
    # perform the refund, if our status is appropriate
    if status == 'processing' || (status == 'queued' && allow_processing_if_queued)
      begin
        created_refund = Stripe::Refund.create({
          charge: charge.stripe_id,
          amount: amount - amount_returned_via_dispute,
          currency: currency,
          reason: stripe_reason
        }.delete_if { |k,v| v.nil? })
      rescue Stripe::StripeError => e
        self.update(status: 'errored', error_message: e.message)
        return
      end
      # MOOSE WARNING: wrap these in a transaction or some such thing?
      if status == 'queued'
        charge.with_lock do
          charge.update(amount_in_queued_refunds: charge.amount_in_queued_refunds - (amount - amount_returned_via_dispute))
        end
      end
      self.update(
        stripe_id: created_refund.id,
        currency: created_refund.currency,
        failure_reason: created_refund.respond_to?('failure_reason') ? created_refund.failure_reason : nil,
        stripe_reason: created_refund.reason,
        receipt_number: created_refund.receipt_number,
        stripe_status: created_refund.status,
        status: status_from_stripe_status(created_refund.status),
        error_message: nil
      )
    end
  end

  private

    def initialize_refund
      self.status ||= must_start_queued? ? 'queued' : 'processing'
      self.amount_returned_via_dispute ||= 0
    end

    def status_from_stripe_status(stripe_status_value = nil)
      stripe_status_value = stripe_status if stripe_status_value.nil?
      return(stripe_status_value == 'canceled' ? 'failed' : stripe_status_value)
    end

    def update_charge_for_refund_creation
      true_amount = amount - amount_returned_via_dispute
      charge.with_lock do
        if true_amount > 0
          charge.update(
            amount_refunded: charge.amount_refunded + true_amount,
            amount_in_queued_refunds: status == 'queued' ? charge.amount_in_queued_refunds + true_amount : charge.amount_in_queued_refunds
          )
        end
      end
    end

    def update_invoice_for_refund_creation
      invoice.with_lock do
        invoice.update(amount_refunded: invoice.amount_refunded + amount)
      end
    end
    
    def set_line_item_refunds
      return unless self.by_line_item.blank?
      # get our line items
      self.by_line_item = []
      ligs = self.invoice.line_item_groups
      # distribute refunds
      amt_left = self.amount
      self.by_line_item = ligs.reverse.map do |lig|
        # how much can we refund to this group?
        total_collected = lig.inject(0){|li| li.collected }
        total_refundable = [amt_left, total_collected].min
        next nil if total_refundable == 0
        # how shall we distribute it?
        total_price = lig.inject(0){|sum,li| sum+li.adjusted_price }.to_d # the price over the total_price is the weight for each element
        total_price = 1.to_d if total_price == 0
        # let's distribute it!
        amounts = lig.map{|li| {
          line_item: li,
          amount: 0
        } }
        lig_amt_left = total_refundable
        while lig_amt > 0
          old_lig_amt = lig_amt_left
          # distribute lig_amt_left proportionally among the line items that haven't been fully refunded, never exceeding the amount actually collected
          relevant_amounts = amounts.select{|amt| amt[:amount] < amt[:line_item].collected }
          total_price = relevant_amounts.inject(0){|sum,amt| sum + amt[:line_item].adjusted_price }
          relevant_amounts.each do |amt|
            amt[:amount] += [(lig_amt_left * li.adjusted_price.to_d / total_price).floor, li.collected - amt[:amount]].min
          end
          lig_amt_left = total_refundable - amounts.inject(0){|sum,amt| amt[:amount] }
          # if the floor functions caused there to be no change, choose the line item with the greatest proportional unrefunded amount, and refund 1 cent to it
          if lig_amt_left == old_lig_amt_left
            to_increment = relevant_amounts.sort{|amt1,amt2| (amt1[:line_item].collected - amt1[:amount]).to_f / (amt1[:line_item].adjusted_price || 1) <=> (amt2[:line_item].collected - amt2[:amount]).to_f / (amt2[:line_item].adjusted_price || 1) }.last
            to_increment[:amount] += 1
            lig_amt_left -= 1
          end
        end
        # paranoid error-fixing, just in case a negative somehow slips in one day
        while lig_amt < 0
          amounts.find{|amt| amt[:amount] > 0 }[:amount] -= 1
          lig_amt += 1
        end
        # we're done with this line itemgroup
        amt_left -= total_refundable
        next amounts
      end.flatten
         .compact
         .map{|li_entry| { 'line_item' => li_entry[:line_item].id, 'amount' => li_entry[:amount] } }
         .select{|li_entry| li_entry['amount'] != 0 }
    end


    def ensure_line_item_refunds_valid
      error_message = nil
      if self.by_line_item.class != ::Array
        error_message = "is invalid"
      elsif self.by_line_item.inject(0){|sum,bli| sum + bli['amount'] } != self.amount
        error_message = "amounts total must match refund amount"
      else
        lis = self.invoice.line_items.to_a
        if self.by_line_item.any?{|bli| !lis.any?{|li| li.id == bli['line_item'].to_i } }
          error_message = "amounts must be for priced-in invoice line items"
        elsif self.by_line_item.any?{|bli| bli['amount'] > lis.find{|li| li.id == bli['line_item'].to_i }.collected }
          error_message = "amounts must not exceed line item collected amounts"
        end
      end
      unless error_message.nil?
        self.errors.add(:by_line_item, error_message)
        throw(:abort)
      end
    end

end
