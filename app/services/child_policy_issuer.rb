class ChildPolicyIssuer < ApplicationService
  attr_accessor :master_policy
  attr_accessor :lease

  def initialize(master_policy, lease)
    @master_policy = master_policy
    @lease = lease
  end

  def call
    new_child_policy = nil
    # Get unit for given lease
    unit = @lease.insurable

    # Fetch community or building
    parent_insurable = @lease.insurable&.insurable

    # NOTE: Do not create MPC if start_date in future
    return nil if @lease.start_date > Time.current.to_date

    master_policy = parent_insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
    if master_policy

      mpc = MasterPolicy::ConfigurationFinder.call(master_policy, parent_insurable)
      raise "No Master Policy Configuration found for Insurable #{parent_insurable.id}" unless mpc

      checking_date = master_policy.effective_date
      checking_date = mpc.program_start_date unless mpc.nil?

      return nil if mpc.program_type == 1

      return nil if checking_date > Time.current.to_date

      policy_number = MasterPolicies::GenerateNextCoverageNumber.run!(master_policy_number: master_policy.number)

      new_child_policy_params = {
        agency: master_policy.agency,
        carrier: master_policy.carrier,
        account: master_policy.account,
        status: 'BOUND',
        policy_coverages_attributes: master_policy.policy_coverages.map do |policy_coverage|
          policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
        end,
        number: policy_number,
        policy_type_id: PolicyType::MASTER_COVERAGE_ID,
        policy: master_policy,
        effective_date: Time.zone.now,
        expiration_date: master_policy.expiration_date,
        system_data: master_policy.system_data,
        policy_users_attributes: [{ user_id: @lease.primary_user.id }]
      }

      new_child_policy = unit.policies.create(new_child_policy_params)
      unit.update(covered: true)
      @lease.update(covered: true)
      new_child_policy
    else
      Rails.logger.info "#DEBUG No master policy found for Insurable (#{parent_insurable.id})"
    end
    new_child_policy
  end

end
