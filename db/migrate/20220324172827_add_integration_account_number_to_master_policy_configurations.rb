class AddIntegrationAccountNumberToMasterPolicyConfigurations < ActiveRecord::Migration[6.1]
  def change
    add_column :master_policy_configurations, :integration_account_number, :string
  end
end
