class SendPocMailJob < ApplicationJob
  queue_as :default

  def perform(policy: , user: )
    UserCoverageMailer.with(policy: policy, user: user)
      .proof_of_coverage()
      .deliver
  end
end
