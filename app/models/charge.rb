# Charge model
# file: app/models/charge.rb

class Charge < ApplicationRecord

  # ActiveRecord Callbacks

  after_initialize :initialize_charge

  after_create :process,
    unless: Proc.new { |chrg| chrg.already_in_on_create }
    
  before_update :set_refund_status,
    if: Proc.new { |chrg| chrg.will_save_change_to_amount_refunded? }

  # ActiveRecord Associations

  belongs_to :invoice

  has_one :user, through: :invoice

  has_many :refunds

  has_many :disputes

  has_many :payments

  # Validations

  validates :status, presence: true

  validates :refund_status, presence: true

  validates :payment_method, presence: true

  validates :amount, presence: true

  validates :amount_refunded, presence: true

  validates :amount_lost_to_disputes, presence: true

  validates :amount_in_queued_refunds, presence: true

  validates :dispute_count, presence: true

  # Enums

  enum status: ['processing', 'pending', 'succeeded', 'failed']

  enum payment_method: ['unknown', 'card', 'bank_account', 'account_credit']

  enum refund_status: ['not_refunded', 'partially_refunded', 'totally_refunded']

  # Methods

  # Already In On Create
  #
  # Check whether we are already in an on_create callback (to prevent a weird bug)
  #
  # Example:
  #   @charge = Charge.find(1)
  #   @charge.already_in_on_create
  #   => false

  def already_in_on_create
    @already_in_on_create
  end


  def mark_succeeded(message = nil)
    update_columns(status: 'succeeded', status_information: message)
    invoice.payment_succeeded
  end


  def mark_failed(message = nil)
    update_columns(status: 'failed', status_information: message)
    invoice.payment_failed
  end


  def react_to_new_dispute
    succeeded = false
    became_disputed = false
    ActiveRecord::Base.transaction do
      # update internals
      self.with_lock do
        became_disputed = (dispute_count == 0)
        succeeded = self.update(dispute_count: dispute_count + 1)
      end
      raise ActiveRecord::Rollback unless succeeded
      # update invoice
      succeeded = invoice.modify_disputed_charge_count(true, false) if became_disputed
      raise ActiveRecord::Rollback unless succeeded
    end
    return succeeded
  end


  def react_to_dispute_closure(dispute_id, amount_lost)
    succeeded = false
    became_undisputed = false
    ActiveRecord::Base.transaction do
      # update internal numbers
      self.with_lock do
        became_undisputed = (dispute_count == 1)
        succeeded = self.update(
          dispute_count: dispute_count - 1,
          amount_lost_to_disputes: amount_lost_to_disputes + amount_lost,
          amount_refunded: amount_refunded + [amount_lost - amount_in_queued_refunds, 0].max,
          amount_in_queued_refunds: [amount_in_queued_refunds - amount_lost, 0].max
        )
      end
      raise ActiveRecord::Rollback unless succeeded
      # apply amount_lost to refunds
      unless amount_lost == 0
        succeeded = true
        refunds.queued.each do |queued_refund|
          queued_refund.with_lock do
            amount_to_credit = [amount_lost, queued_refund.amount - queued_refund.amount_returned_via_dispute].min
            if queued_refund.apply_dispute_payout(amount_to_credit)
              amount_lost -= amount_to_credit
            else
              succeeded = false
            end
          end
          break if amount_lost == 0
        end
      end
      succeeded ||= (amount_lost == 0) # we succeeded if no apply_dispute_payout call failed, or if some failed but we applied the full amount_lost as credit anyway
      raise ActiveRecord::Rollback unless succeeded
      # create a bookkeeping refund for any amount left over
      unless amount_lost == 0
        succeeded = refunds.create(
          amount: amount_lost,
          amount_returned_via_dispute: amount_lost,
          status: 'succeeded_via_dispute_payout',
          full_reason: "payout for dispute ##{dispute_id}"
        )
        raise ActiveRecord::Rollback unless succeeded
      end
      # update invoice
      succeeded = invoice.modify_disputed_charge_count(false, true) if became_undisputed
      raise ActiveRecord::Rollback unless succeeded
    end
    return succeeded
  end


  def apply_refund(amount_to_refund, full_reason = nil, stripe_reason = nil)
    return({ success: false, errors: { amount: ["sum of past refunds cannot exceed charge total"] } }) if amount_to_refund > amount - amount_refunded
    return({ success: true }) if amount_to_refund == 0
    created_refund = refunds.new({
      amount: amount_to_refund,
      full_reason: full_reason,
      stripe_reason: stripe_reason
    })
    return({ success: true }) if created_refund.save
    return({ success: false, errors: created_refund.errors })
  end

  def refunds_must_start_queued?
    invoice.refunds_must_start_queued?
  end

  private


    def initialize_charge
      self.status ||= 'processing'
      # leave nil status_information nil
      self.refund_status ||= 'not_refunded'
      self.payment_method ||= 'unknown'
      # leave nil amount nil
      self.amount_refunded ||= 0
      self.amount_lost_to_disputes ||= 0
      self.amount_in_queued_refunds ||= 0
      self.dispute_count ||= 0
      # leave nil stripe_id nil
      # leave nil invoice nil
    end


    def pay_attempt_succeeded(stripe_charge_id, the_payment_method, message = nil)
      update_columns(status: 'succeeded', stripe_id: stripe_charge_id, payment_method: the_payment_method, status_information: message)
      invoice.payment_succeeded
    end

    def pay_attempt_failed(stripe_charge_id, the_payment_method, message = nil)
      update_columns(status: 'failed', stripe_id: stripe_charge_id, payment_method: the_payment_method, status_information: message)
      invoice.payment_failed
    end

    def pay_attempt_pending(stripe_charge_id, the_payment_method, message = nil)
      update_columns(status: 'pending', stripe_id: stripe_charge_id, payment_method: the_payment_method, status_information: message)
    end

    def stripe_id_is_stripe_source
      return(!stripe_id.nil? && stripe_id.start_with?('src_', 'card_', 'ba_'))
    end

    def stripe_id_is_stripe_token
      return(!stripe_id.nil? && stripe_id.first(4) == 'tok_')
    end
    
    def set_refund_status
      if amount_refunded == 0
        self.refund_status = 'not_refunded'
      elsif amount_refunded == amount
        self.refund_status = 'totally_refunded'
      else
        self.refund_status = 'partially_refunded'
      end
    end

    # Process
    #
    # Build charge and sync to stripe
    #
    # Example:
    #   @charge = Charge.find(1)
    #   @charge.process()
    #   => { success: true }

    def process
      # setup
      @already_in_on_create = true
      stripe_source = nil
      if stripe_id_is_stripe_source
        stripe_source = stripe_id
      elsif stripe_id_is_stripe_token # MOOSE WARNING: probably remove this
        # retrieve the token
        token = nil
        begin
          token = Stripe::Token.retrieve(stripe_id)
        rescue Stripe::StripeError => e
          pay_attempt_failed(nil, 'unknown', "Payment processor error: #{e.message}")
          remove_instance_variable(:@already_in_on_create)
          return
        end
        # flee if something terrible has happened
        if token[token['type']].nil?
          pay_attempt_failed(nil, 'unknown', "Payment processor error: returned payment source of type '#{token['type']}'")
          remove_instance_variable(:@already_in_on_create)
          return
        elsif token[token['type']]['id'].nil?
          pay_attempt_failed(nil, 'unknown', "Payment processor error: returned payment source with null id")
          remove_instance_variable(:@already_in_on_create)
          return
        end
        # rip the card or bank account out of the token for our use
        stripe_source = token[token['type']]['id']
      end
      # processing
      if status != 'processing'
        pay_attempt_failed(nil, 'unknown', "Attempted to process payment attempt which has already been processed")
        remove_instance_variable(:@already_in_on_create)
        return
      else
        # create charge
        begin
	        descriptor = invoice.get_descriptor
          stripe_charge = Stripe::Charge.create({
            amount: amount,
            currency: 'usd',
            description: "#{ descriptor }, Invoice ##{invoice.number}",
            customer: invoice.user.stripe_id,
            source: stripe_source
          }.delete_if { |k,v| v.nil? })
        rescue Stripe::StripeError => e
          pay_attempt_failed(nil, 'unknown', "Payment processor error: #{e.message}")
          remove_instance_variable(:@already_in_on_create)
          return
        end
        
        # handle charge status
        if stripe_charge.nil?
          pay_attempt_failed(nil, 'unknown', "Payment processor failed to create charge") # this should never happen, but just in case...
        else
          the_payment_method = stripe_charge['source'].nil? || !['card', 'bank_account'].include?(stripe_charge['source']['object']) ? 'unknown' : stripe_charge['source']['object']
          if stripe_charge['status'] == 'failed'
            pay_attempt_failed(stripe_charge['id'], the_payment_method, "Payment processor reported failure: #{stripe_charge['failure_message'] || 'unknown error'} (code #{stripe_charge['failure_code'] || 'null'})")
          elsif stripe_charge['status'] == 'succeeded'
            pay_attempt_succeeded(stripe_charge['id'], the_payment_method)
          elsif stripe_charge['status'] == 'pending'
            pay_attempt_pending(stripe_charge['id'], the_payment_method)
          else
            pay_attempt_failed(stripe_charge['id'], the_payment_method, "Unknown error: charge status '#{stripe_charge['status']}'") # this should never happen, but just in case...
          end
        end
      end
      remove_instance_variable(:@already_in_on_create)
    end

end
