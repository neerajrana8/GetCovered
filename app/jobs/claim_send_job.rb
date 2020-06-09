class ClaimSendJob < ApplicationJob
  queue_as :mailer

  def perform(user, *args)
    user = user
    UserClaimMailer.with(user: user).claim_creation_email.deliver
  end
end
