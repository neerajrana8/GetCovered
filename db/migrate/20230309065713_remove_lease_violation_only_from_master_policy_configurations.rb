class RemoveLeaseViolationOnlyFromMasterPolicyConfigurations < ActiveRecord::Migration[6.1]
  def change
    remove_column :master_policy_configurations, :lease_violation_only
  end
end
