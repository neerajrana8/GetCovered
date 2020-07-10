class AutomaticMasterCoveragePolicyIssueJob < ApplicationJob
  queue_as :default
  
  def perform(policy_id)
    master_policy = Policy.find_by(id: policy_id)
    return if master_policy.nil? || master_policy.policy_type.designation != 'MASTER'

    master_policy.insurables.each do |insurable|      
      insurable.units&.each do |unit|
        if unit.policies.empty? && unit.leases.empty?
          last_policy_number = master_policy.policies.maximum('number')
          unit.policies.create(
            agency: master_policy.agency,
            carrier: master_policy.carrier,
            account: master_policy.account,
            policy_coverages: master_policy.policy_coverages,
            number: last_policy_number.nil? ? "#{master_policy.number}_1" : last_policy_number.next,
            policy_type_id: PolicyType::MASTER_COVERAGE_ID,
            policy: master_policy,
            effective_date: master_policy.effective_date,
            expiration_date: master_policy.expiration_date
          )
        end
      end
    end

    AutomaticMasterCoveragePolicyIssueJob.set(wait: 1.day).perform_later(policy_id)
  end
end
