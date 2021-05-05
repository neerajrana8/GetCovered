class AutomaticMasterCoveragePolicyIssueJob < ApplicationJob
  queue_as :default
  
  def perform(policy_id)
    master_policy = Policy.find_by(id: policy_id)
    return if master_policy.nil? || master_policy.policy_type_id != PolicyType::MASTER_ID

    master_policy.insurables.each do |insurable|      
      insurable.units&.each do |unit|
        if unit.policies.current.empty? && !unit.occupied?
          last_policy_number = master_policy.policies.maximum('number')
          unit.policies.create(
            agency: master_policy.agency,
            carrier: master_policy.carrier,
            account: master_policy.account,
            status: 'BOUND',
            policy_coverages_attributes: master_policy.policy_coverages.map do |policy_coverage|
              policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
            end,
            number: last_policy_number.nil? ? "#{master_policy.number}_1" : last_policy_number.next,
            policy_type_id: PolicyType::MASTER_COVERAGE_ID,
            policy: master_policy,
            effective_date: Time.zone.now,
            expiration_date: master_policy.expiration_date,
            system_data: master_policy.system_data
          )
          unit.update(covered: true)
        end
      end
    end
  end
end
