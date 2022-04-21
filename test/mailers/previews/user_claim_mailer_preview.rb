class UserClaimMailerPreview < ActionMailer::Preview

  def claim_creation_email
    claim = Claim.first
    user = claim.claimant
    UserClaimMailer.with(user: user, claim: claim).claim_creation_email
  end
end
