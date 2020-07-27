class ClaimSendJob < ApplicationJob
  queue_as :default

  def perform(user, claim_id)
    user = user
    claim = user.claims.find(claim_id)
    UserClaimMailer.with(user: user, claim: claim).claim_creation_email.deliver
  end
end
