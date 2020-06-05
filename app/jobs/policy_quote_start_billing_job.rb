class PolicyQuoteStartBillingJob < ApplicationJob
  queue_as :default

  def perform(policy:, issue:)
    return if policy.nil?
    
    policy.send(issue)
    
    UserCoverageMailer.with(policy: policy, user: policy.primary_user).proof_of_coverage.deliver if policy.policy_type_id != 5
    UserCoverageMailer.with(policy: policy, user: policy.primary_user).all_documents.deliver if policy.policy_type_id == 5
    
    policy.policy_users.each(&:invite)
  end
end
