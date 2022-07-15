class StripeRefund < ApplicationRecord

  belongs_to :refund
  belongs_to :stripe_charge
  
  has_one :invoice,
    through: :refund
  
  enum status: {
    awaiting_execution: 0,
    errored: 1,
    failed: 2,
    pending: 3,
    succeeded: 4,
    succeeded_manually: 5
  }
  enum stripe_reason: {
    requested_by_customer: 0,
    duplicate: 1,
    fraudulent: 2
  }
  enum stripe_status: {
    pending: 0,
    succeeded: 1,
    failed: 2,
    canceled: 3
  }, _prefix: true
  
  def balance_transaction
    Stripe::Refund.retrieve(self.stripe_id).balance_transaction rescue nil
  end
  
  def execute
    self.with_lock do
      return unless self.status == 'awaiting_execution'
      created_refund = nil
      # try to create the refund
      begin
        created_refund = Stripe::Refund.create({
          charge: self.stripe_charge.stripe_id,
          amount: self.amount,
          reason: self.stripe_reason,
          metadata: {
            metadata_version: 1,
            stripe_refund_id: self.id,
            invoice: self.invoice&.number,
            reasons: self.full_reasons.join("\n")[0...500]
          }
        }.compact)
      rescue Stripe::StripeError => e
        self.update(status: 'errored', error_message: "Stripe error on refund creation: #{e.message}")
        return
      rescue
        self.update(status: 'errored', error_message: "Unknown error")
        return
      end
      # update ourselves, woot woot
      begin
        new_status = status_from_stripe_status(created_refund.status)
        unless self.update(
          stripe_id: created_refund.id,
          failure_reason: created_refund.respond_to?(:failure_reason) ? created_refund.failure_reason : nil,
          stripe_reason: created_refund.reason,
          receipt_number: created_refund.receipt_number,
          stripe_status: created_refund.status,
          status: new_status,
          error_message: new_status == 'errored' ? "Unknown stripe status '#{refund_hash['status']}'" : nil
        )
          self.update(status: 'errored', error_message: "Failed to update (stripe id was '#{created_refund.id}'), errors: #{self.errors.to_h}")
        end
      rescue
        self.update(status: 'errored', error_message: "Unknown error after refund creation. Stripe id was '#{created_refund && created_refund.respond_to?(:id) ? created_refund.id : ""}'.")
      end
    end
  end
  
  def update_from_stripe_hash(refund_hash)
    new_status = status_from_stripe_status(refund_hash['status'])
    update(
      amount: refund_hash['amount'],
      failure_reason: refund_hash['failure_reason'],
      stripe_reason: refund_hash['reason'],
      receipt_number: refund_hash['receipt_number'],
      stripe_status: refund_hash['status'],
      status: new_status,
      error_message: new_status == 'errored' ? "Unknown stripe status '#{refund_hash['status']}'" : nil
    ) # most of these are not expected to be able to change, but are included for completeness
  end
  
  private

    def status_from_stripe_status(stripe_status_value = nil)
      stripe_status_value = self.stripe_status if stripe_status_value.nil?
      case stripe_status_value || self.stripe_status
        when 'succeeded'
          'succeeded'
        when 'failed', 'canceled'
          'failed'
        when 'pending'
          'pending'
        else
          'errored'
      end
    end


end
