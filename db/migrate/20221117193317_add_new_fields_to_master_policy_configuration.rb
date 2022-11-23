class AddNewFieldsToMasterPolicyConfiguration < ActiveRecord::Migration[6.1]
  def change
    add_column :master_policy_configurations, :admin_fee, :integer, :default => 0
    add_column :master_policy_configurations, :force_admin_fee, :integer
    add_column :master_policy_configurations, :prorate_admin_fee, :boolean, :default => false
  end
end
