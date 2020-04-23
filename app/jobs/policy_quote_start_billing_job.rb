class PolicyQuoteStartBillingJob < ApplicationJob
  queue_as :default

  def perform(policy:, issue:)
    return if policy.nil?
    
    policy.send(issue)
    
    #UserCoverageMailer.with(policy: policy, user: policy.primary_user).proof_of_coverage.deliver
    
    policy.policy_users.each(&:invite)
  end
end
