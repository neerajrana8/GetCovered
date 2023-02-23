module ChildPolicy
  # NOTE: this is a child policy (master policy coverage type) configuration finder service;
  #       this service additionally links found MPC to child policy if it wasn't linked before
  class MPConfigurationFinder < ApplicationService
    attr_accessor :policy

    def initialize(policy)
      @policy = policy
    end

    def call
      # NOTE: return MPC in case it is already linked (it is not for old child policies)
      return @policy.master_policy_configuration if @policy.master_policy_configuration_id

      # NOTE: link MPC to the polocy in case it wasn't linked before
      mpc = MasterPolicy::ConfigurationFinder.call(master_policy, insurable, available_lease_date)
      @policy.update!(master_policy_configuration_id: mpc.id)
      mpc
    end

    private

    def lease
      @lease ||= @policy.latest_lease(lease_status: ['pending', 'current'])
    end

    def insurable
      @insurable ||= @policy.primary_insurable.parent_community
    end

    def available_lease_date
      lease.nil? ? DateTime.current.to_date : lease.sign_date.nil? ? lease.start_date : lease.sign_date
    end

    def master_policy
      @master_policy ||= insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
    end
  end
end
