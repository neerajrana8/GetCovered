class StripeCommissionPayoutJob < ActiveJob::Base
  queue_as :default

  def perform(commission_id)
    commission = Commission.find_by(id: commission_id)
    return unless commission

    commission.send_stripe_payout
  end
end
