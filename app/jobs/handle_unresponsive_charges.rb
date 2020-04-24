class HandleUnresponsiveChargesJob < ApplicationJob
  queue_as :default
  before_perform :set_charges

  def perform(*_args)
    @charges.each do |charge|
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
        when 'succeeded'
          charge.mark_succeeded
        when 'failed'
          charge.mark_failed("Payment processor reported failure: #{stripe_charge.failure_message || 'unknown error'} (code stripe_charge.failure_code || 'null'})")
        when 'pending'
          # do nothing
        else # either stripe_charge is nil or it is somehow invalid (stripe api guarantees succeeded/pending/failed statuses)
          charge.mark_failed("Payment processor failed to record valid charge")
      end
    end
  end

  private

  def set_charges
    @charges = Charge.pending.where("created_at < '#{(Time.current - 14.days).to_s(:db)}'")
  end
end
