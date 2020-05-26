class CoverageReminderJob < ApplicationJob
  queue_as :default
  
  def perform(policy_id, first = true)
    coverage_policy = Policy.find_by(id: policy_id)
    return if coverage_policy.nil? || coverage_policy.primary_insurable&.policies&.count&.>(1)
    if first
      UserCoverageMailer.with(user: coverage_policy.primary_user, policy: coverage_policy).coverage_required.deliver
    else
      UserCoverageMailer.with(user: coverage_policy.primary_user, policy: coverage_policy).coverage_required_follow_up.deliver
    end
  end
  
end
