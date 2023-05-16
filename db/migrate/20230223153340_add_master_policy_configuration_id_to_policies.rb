class AddMasterPolicyConfigurationIdToPolicies < ActiveRecord::Migration[6.1]
  def change
    add_column :policies, :master_policy_configuration_id, :integer
  end
end
