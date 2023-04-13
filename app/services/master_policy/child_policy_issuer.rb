module MasterPolicy
  # ChildPolicy Issuer Service
  class ChildPolicyIssuer < ApplicationService
    attr_accessor :master_policy
    attr_accessor :lease
    attr_accessor :users

    def initialize(master_policy, lease, users = nil)
      @master_policy = master_policy
      @lease = lease
      @users = users
    end

    def call
      # Get unit for given lease
      @unit = @lease.insurable

      # Fetch community or building
      @parent_insurable = @lease.insurable&.insurable

      # NOTE: Do not create MPC if start_date in future
      raise 'Invalid lease' unless lease_valid?
      raise 'Master policy not matched' unless master_policy_matched?

      @mpc = master_policy_configuration

      raise 'Invalid program type' unless program_type_valid?
      raise 'Date invalid' unless  checking_date_valid?

      enroll
    end

    private

    def enroll
      ActiveRecord::Base.transaction do
        new_child_policy = create_child_policy
        cover_unit
        cover_lease
        notify_users(new_child_policy, @unit) if @mpc.program_type == :opt_out
        new_child_policy
      end
    end

    def master_policy_configuration
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

    def policy_users
      users_source = @lease.users
      users_source = @users unless @users.nil?

      users = []
      users_source.each do |u|
        users << { user_id: u.id }
      end
      users
    end

    def effective_date
      @lease.start_date
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
        effective_date: effective_date,
        expiration_date: @lease.end_date,
        system_data: @master_policy.system_data,
        policy_users_attributes: policy_users,
        master_policy_configuration_id: @mpc&.id
      }
      @unit.policies.create(new_child_policy_params)
    end

    def assign_lease_users_to_policy(policy)
      @lease.users do |u|
        policy.users << u
      end
      policy.save
    end

    def lease_valid?
      @lease.start_date <= Time.current.to_date && !@lease.defunct
    end

    def notify_users(policy, insurable)
      users = User.where(id: policy_users.map{ |x| x[:user_id]})
      users.each do |user|
        Compliance::PolicyMailer.with(organization: policy.account ? policy.account : policy.agency)
          .enrolled_in_master(user: user,
                              community: insurable.parent_community(),
                              force: true).deliver_now
      end
    end
  end
end
