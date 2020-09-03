class MasterCoverageCancelJob < ApplicationJob
  queue_as :default
  
  def perform(policy_id)
    master_policy = Policy.find_by(id: policy_id)
    return if master_policy.nil? || master_policy.policy_type_id != PolicyType::MASTER_ID

    master_policy.policies.master_policy_coverages.each do |policy|
      policy.update(status: 'CANCELLED', cancellation_date: Time.zone.now, expiration_date: Time.zone.now)
      policy.insurables.take.update(covered: false)
    end

    master_policy.update(status: 'CANCELLED', cancellation_date: Time.zone.now, expiration_date: Time.zone.now)
  end
end
