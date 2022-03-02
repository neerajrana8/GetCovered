class AddEnabledToMasterPolicyConfiguration < ActiveRecord::Migration[6.1]
  def up
    add_column :master_policy_configurations, :enabled, :boolean, default: false
    MasterPolicyConfiguration.find_each { |mpc| mpc.update enabled: true if mpc.enabled.nil? }
  end

  def down
    remove_column :master_policy_configurations, :enabled
  end
end
