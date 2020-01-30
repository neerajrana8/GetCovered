class PolicyQuoteStartBillingJob < ApplicationJob
  queue_as :default

  def perform(policy: , issue:)
    policy.send(issue)
    policy.policy_users.each do |pu|
      UserCoverageMailer.with(policy: policy, user: pu.user).proof_of_coverage().deliver if pu.user
    end
  end
end
