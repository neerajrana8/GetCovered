class AutomaticMasterCoveragePolicyIssueJob < ApplicationJob
  queue_as :default
  
  def perform(policy_id)
    master_policy = Policy.find_by(id: policy_id)
    return if master_policy.nil? || master_policy.policy_type.designation != 'MASTER'

    master_policy.insurables.each do |insurable|      
      insurable.units&.each do |unit|
        if unit.policies.empty? && unit.leases&.count&.zero?
          unit.policies.create(
            agency: master_policy.agency, 
            carrier: master_policy.carrier, 
            account: master_policy.account,
            policy_coverages: master_policy.policy_coverages,
            policy_type: PolicyType.find_by(designation: 'MASTER-COVERAGE'),
            policy: master_policy,
            effective_date: Date.today
          )
        end
      end
    end
    AutomaticMasterCoveragePolicyIssueJob.set(wait: 1.day).perform_later(policy_id)
  end
end
