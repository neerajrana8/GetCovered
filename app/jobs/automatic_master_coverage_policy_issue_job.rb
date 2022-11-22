#TODO: can be deleted because can't find where it used now
class AutomaticMasterCoveragePolicyIssueJob < ApplicationJob
  queue_as :default

  def perform(policy_id)
    master_policy = Policy.find_by(id: policy_id)
    return if master_policy.nil? || PolicyType::MASTER_IDS.exclude?(master_policy.policy_type_id)

    master_policy.insurables.each do |insurable|
      insurable.units_relation&.each do |unit|
        if unit.
          policies.
          where(policy_type_id: PolicyType::MASTER_MUTUALLY_EXCLUSIVE[master_policy.policy_type_id]).
          current.
          empty? && unit.occupied?
          policy_number = MasterPolicies::GenerateNextCoverageNumber.run!(master_policy_number: master_policy.number)
          unit.policies.create(
            agency: master_policy.agency,
            carrier: master_policy.carrier,
            account: master_policy.account,
            status: 'BOUND',
            policy_coverages_attributes: master_policy.policy_coverages.map do |policy_coverage|
              policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
            end,
            number: policy_number,
            policy_type: master_policy.policy_type.coverage,
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
