module Insurables
  class MasterPolicyAutoAssignJob < ApplicationJob
    queue_as :default

    def perform
      policy_insurables = PolicyInsurable.
        joins(:policy).
        where(policy_insurables: { auto_assign: true }, policies: { policy_type_id: PolicyType::MASTER_ID }).
        where('expiration_date > ?', Time.zone.now)

      policy_insurables.each do |policy_insurable|
        policy = policy_insurable.policy
        policy_insurable.insurable&.units&.each do |unit|
          next unless unit.policies.current.empty? && unit.leases.empty?

          last_policy_number = policy.policies.maximum('number')
          unit.policies.create(
            agency: policy.agency,
            carrier: policy.carrier,
            account: policy.account,
            status: 'BOUND',
            policy_coverages_attributes: policy.policy_coverages.map do |policy_coverage|
              policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
            end,
            number: last_policy_number.nil? ? "#{policy.number}_1" : last_policy_number.next,
            policy_type_id: PolicyType::MASTER_COVERAGE_ID,
            policy: policy,
            effective_date: Time.zone.now,
            expiration_date: policy.expiration_date,
            system_data: policy.system_data
          )
          unit.update(covered: true)
        end
      end
    end
  end
end
