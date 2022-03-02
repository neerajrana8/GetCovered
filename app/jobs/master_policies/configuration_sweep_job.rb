module MasterPolicies
  class ConfigurationSweep < ApplicationJob
    queue_as :default
    before_perform :set_configurations

    def perform(*)
      @configurations.each do |config|

      end
    end

    private
    def set_configurations
      @configurations = MasterPolicyConfiguration.where(enabled: true)
    end

  end
end
