class HandleUnresponsiveChargesJob < ApplicationJob
  queue_as :default
  before_perform :set_charges

  def perform(*_args)
    # try to handle charges that seem to be stuck in the 'processing' state
    @processing_charges.each do |charge|
      # manually re-attempt payment and then call the finish handler if it's still 'processing'
      charge.attempt_payment
      charge.process if charge.reload.status == 'processing'
    end
    # try to handle charges whose .process callbacks seem to have failed
    @unprocessed_charges.each do |charge|
      charge.process
    end
    # try to handle long-term pending charges
    @pending_charges.each do |charge|
      # try retrieving from stripe
      stripe_charge = nil
      unless charge.stripe_id.nil?
        begin
          stripe_charge = Stripe::Charge.retrieve(charge.stripe_id)
        rescue Stripe::StripeError => e
          stripe_charge = nil # WARNING: add some sort of logging at some point?
        end
      end
      # handle stripe charge data
      case stripe_charge&.status
        when 'pending'
          # do nothing; it really IS still pending
        when 'succeeded'
          charge.update(status: 'succeeded')
        when 'failed'
          charge.update(
            status: 'failed',
            error_info: "#{stripe_charge['failure_message'] || "Stripe charged failed with no failure_message"}",
            client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_rejection', code: "#{stripe_charge['failure_code'] || 'unknown reason'}")
          )
        else # either stripe_charge is nil or it is somehow invalid (stripe api guarantees succeeded/pending/failed statuses)
          charge.update(
            status: 'mysterious',
            error_info: "Stripe charge was marked 'pending' for a long time; investigation revealed #{stripe_charge.nil? ? "charge's stripe_id does not correspond to a charge in Stripe's system" : "charge has unknown status on Stripe ('#{stripe_charge['status']}')"}",
            client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_mystery')
          )
      end
    end
  end

  private

  def set_charges
    @processing_charges = ::StripeCharge.processing.where("created_at < ?", Time.current - 4.hours)
    @unprocessed_charges = ::StripeCharge.where.not(status: 'processing').where(invoice_aware: false).where("status_changed_at < ?", Time.current - 4.hours)
    @pending_charges = ::StripeCharge.pending.where("created_at < ?", Time.current - 14.days)
  end
end
