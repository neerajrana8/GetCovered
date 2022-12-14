module Insurables
  class MasterPolicyAutoAssignJob < ApplicationJob
    queue_as :default

    def perform
      policy_insurables = PolicyInsurable.
        joins(:policy).
        where(policy_insurables: { auto_assign: true }, policies: { policy_type_id: PolicyType::MASTER_IDS }).
        where('expiration_date > ?', Time.zone.now)

      policy_insurables.each do |policy_insurable|
        policy = policy_insurable.policy

        policy_insurable.insurable&.units&.each do |unit|

          # NOTE: Check of existing valid lease, if exists then continue to issue MPC (master policy child, or child policy)
          lease = Lease.where('end_date > ?', Time.current.to_date).find_by(insurable_id: unit.id, status: 'current')
          next unless lease

          # NOTE: removed check for occupied because when lease is create unit is already occupied
          # but have no master policy coverage
          # PREVIOUS: next unless unit.policies.current.empty? && !unit.occupied?
          next unless unit.policies.current.empty?

          policy_number = MasterPolicies::GenerateNextCoverageNumber.run!(master_policy_number: policy.number)

          unit.policies.create(
            agency: policy.agency,
            carrier: policy.carrier,
            account: policy.account,
            status: 'BOUND',
            policy_coverages_attributes: policy.policy_coverages.map do |policy_coverage|
              policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
            end,
            number: policy_number,
            # TODO: Must be id of Master policy coverage policy type
            policy_type_id: PolicyType::MASTER_COVERAGE_ID, # policy.policy_type.coverage,
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
