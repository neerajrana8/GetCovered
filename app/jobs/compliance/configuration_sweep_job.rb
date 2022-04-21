module Compliance
  class ConfigurationSweepJob < ApplicationJob
    queue_as :default
    before_perform :set_configurations

    def perform(*)
      # @configurations.each do |config|
      #   configurable = config.configurable
      #   master_policy = configurable.policies.where(policy_type_id:2, carrier_id: 2).take
      #   leases = configurable.leases.where("start_date >= :date AND covered = false", date: config.program_start_date)
      #   leases.each do |lease|
      #     if Time.current.to_date >= lease.start_date + config.grace_period.days
      #       master_policy.qbe_specialty_issue_coverage(lease.insurable, lease.users, lease.start_date, true, primary_user: lease.primary_user)
      #     end
      #   end
      # end
    end

    private
    def set_configurations
      @configurations = MasterPolicyConfiguration.where(enabled: true)
    end

  end
end
