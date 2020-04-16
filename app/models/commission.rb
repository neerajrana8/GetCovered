class Commission < ApplicationRecord
  belongs_to :policy_premium
  belongs_to :commission_strategy
  belongs_to :commissionable, polymorphic: true
  
  def approve
    update_attribute(:approved, true)
    if distributes
      # TODO: refactor distributes attribute from Date to DateTime
      StripeCommissionPayoutJob.set(wait_until: distributes.to_datetime).perform_later(id)
    else
      StripeCommissionPayoutJob.perform_later(id)
    end
  end
  
  def send_stripe_payout
    begin
      Stripe::Transfer.create({
        amount: amount,
        currency: 'usd',
        destination: commissionable&.stripe_id
      })
    rescue Stripe::InvalidRequestError => exception
      # TODO: once ModelError branch is merged, refactor to create errors to Commission
      return { error: exception.message }
    end
    update_attribute(:paid, true)
  end
end