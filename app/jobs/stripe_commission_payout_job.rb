class StripeCommissionPayoutJob < ActiveJob::Base
  queue_as :default

  def perform(commissions = nil)
    commissions ||= ::Commission.where(status: 'approved', payout_method: 'stripe')
    commissions.each do |commission|
      commission.pay_with_stripe
    end
  end
  
end
