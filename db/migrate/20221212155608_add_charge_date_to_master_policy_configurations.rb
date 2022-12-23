class AddChargeDateToMasterPolicyConfigurations < ActiveRecord::Migration[6.1]
  def change
    add_column :master_policy_configurations, :charge_date, :integer
  end
end
