module Compliance
  class LeaseIntroJob < ApplicationJob
    queue_as :default
    before_perform :set_configurations

    def perform(*)
      @configurations.each do |config|
        configurable = config.configurable
        master_policy = configurable.policies.where(policy_type_id:2, carrier_id: 2).take
        leases = configurable.leases.where(created_at: DateTime.current - 1.day)
      end
    end

    private
    def set_configurations
      @configurations = MasterPolicyConfiguration.where(enabled: true)
    end

  end
end