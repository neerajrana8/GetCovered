module MasterPolicy
  # ChildPolicy Issuer Service
  class ChildPolicyIssuer < ApplicationService
    attr_accessor :master_policy
    attr_accessor :lease

    def initialize(master_policy, lease)
      @master_policy = master_policy
      @lease = lease
    end

    def call
      # Get unit for given lease
      @unit = @lease.insurable

      # Fetch community or building
      @parent_insurable = @lease.insurable&.insurable

      # NOTE: Do not create MPC if start_date in future
      return nil unless lease_valid?
      return nil unless master_policy_matched?

      @mpc = master_policy_confiuration

      return nil unless program_type_valid?
      return nil unless  checking_date_valid?

      new_child_policy = create_child_policy
      cover_unit
      cover_lease

      new_child_policy
    end

    private

    def master_policy_confiuration
      ::MasterPolicy::ConfigurationFinder.call(@master_policy, @parent_insurable)
    end

    def master_policy_matched?
      master_policy_taken = @parent_insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
      master_policy_taken&.id == @master_policy.id
    end

    def checking_date_valid?
      checking_date < Time.current.to_date
    end

    def checking_date
      checking_date = @master_policy.effective_date
      checking_date = @mpc.program_start_date unless @mpc.nil?
      checking_date
    end

    def program_type_valid?
      @mpc.program_type != 1
    end

    def cover_unit
      @unit.update(covered: true)
    end

    def cover_lease
      @lease.update(covered: true)
    end

    def policy_coverages
      @master_policy.policy_coverages.map do |policy_coverage|
        policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
      end
    end

    def new_child_policy_number
      MasterPolicies::GenerateNextCoverageNumber.run!(master_policy_number: @master_policy.number)
    end

    def create_child_policy
      new_child_policy_params = {
        agency: @master_policy.agency,
        carrier: @master_policy.carrier,
        account: @master_policy.account,
        status: 'BOUND',
        policy_coverages_attributes: policy_coverages,
        number: new_child_policy_number,
        policy_type_id: PolicyType::MASTER_COVERAGE_ID,
        policy: @master_policy,
        effective_date: Time.zone.now,
        expiration_date: @master_policy.expiration_date,
        system_data: @master_policy.system_data,
        policy_users_attributes: [{ user_id: @lease.primary_user.id }]
      }
      @unit.policies.create(new_child_policy_params)
    end

    def lease_valid?
      @lease.start_date < Time.current.to_date
    end

  end

end
