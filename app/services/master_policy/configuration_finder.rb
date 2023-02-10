module MasterPolicy

  # Master policy configuration finder service
  class ConfigurationFinder < ApplicationService

    attr_accessor :insurable
    attr_accessor :cutoff_date
    attr_accessor :master_policy

    def initialize(master_policy, insurable, cutoff_date = DateTime.now)
      @master_policy = master_policy
      @insurable = insurable
      @cutoff_date = cutoff_date || DateTime.now.to_date
    end

    def call
      master_policy_configuration = nil

      raise 'Insurable is nil' if @insurable.nil?

      @community = fetch_community

      raise "Community not found for Insurable #{@insurable.id}" unless community_found?

      raise "MasterPolicy doesn't assigned for this insurable ID=#{@insurable.id}" unless master_policy_applied_to_insurable?

      if community_configuration_found?
        master_policy_configuration = community_configuration
      elsif master_policy_configuration_found?
        master_policy_configuration = self_configuration
      elsif account_configuration_found?
        master_policy_configuration = account_configuration
      end

      master_policy_configuration
    end

    private

    def community_configuration_found?
      !@community.master_policy_configurations.where(carrier_policy_type: carrier_policy_type).nil?
    end

    def master_policy_configuration_found?
      !@master_policy.master_policy_configurations.nil?
    end

    def account_configuration_found?
      @master_policy.account.master_policy_configurations.where(carrier_policy_type: carrier_policy_type).positive?
    end

    def fetch_community
      community = nil
      if InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(@insurable.insurable_type_id)
        community = @insurable
      elsif insurable_types.include?(@insurable.insurable_type_id)
        community = @insurable.parent_community
      end
      community
    end

    def insurable_types
      InsurableType::RESIDENTIAL_BUILDINGS_IDS + InsurableType::RESIDENTIAL_UNITS_IDS
    end

    def community_found?
      !@community.nil?
    end

    def master_policy_applied_to_insurable?
      return false unless @master_policy

      @master_policy.insurables.include?(@community)
    end

    def carrier_policy_type
      carrier_policy_type = CarrierPolicyType.find_by(
        carrier_id: @master_policy.carrier_id,
        policy_type: @master_policy.policy_type_id
      )

      unless carrier_policy_type
        raise "CarrierPolicyType not found for Carrier (#{@master_policy.carrier_id}), " \
              "PolicyType (#{@master_policy.policy_type_id})"
      end
      carrier_policy_type
    end

    def account_configuration
      @master_policy.account.master_policy_configurations
        .where(carrier_policy_type: carrier_policy_type)
        .where('program_start_date < ?', @cutoff_date)
        .order('program_start_date desc').limit(1).take
    end

    def self_configuration
      @master_policy.master_policy_configurations
        .where('program_start_date < ?', @cutoff_date)
        .order('program_start_date desc').limit(1).take
    end

    def community_configuration
      @community.master_policy_configurations
        .where(carrier_policy_type: carrier_policy_type)
        .where('program_start_date < ?', @cutoff_date)
        .order('program_start_date desc').limit(1).take
    end
  end
end
