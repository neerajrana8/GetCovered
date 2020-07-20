class MasterCoverageCancelJob < ApplicationJob
  queue_as :default
  
  def perform(policy_id)
    master_policy = Policy.find_by(id: policy_id)
    return if master_policy.nil? || master_policy.policy_type.designation != 'MASTER'

    master_policy.policies.master_policy_coverages do |policy|
      policy.update(status: 'CANCELLED', cancellation_date_date: Time.zone.now, expiration_date: Time.zone.now)
    end

    master_policy.update(status: 'CANCELLED', cancellation_date_date: Time.zone.now, expiration_date: Time.zone.now)
  end
end
