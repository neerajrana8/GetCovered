class Refund < ApplicationRecord
    # ActiveRecord Callbacks

  after_initialize :initialize_refund

  after_create :update_charge_for_refund_creation

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
      charge.with_lock
        # update charge
        true_amount = amount - amount_returned_via_dispute
        if true_amount > 0
          charge.update(
            amount_refunded: charge.amount_refunded + true_amount,
            amount_in_queued_refunds: status == 'queued' ? charge.amount_in_queued_refunds + true_amount : charge.amount_in_queued_refunds
          )
        end
      end
    end

end
