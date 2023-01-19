class ChangeMasterPolicyConfigurationIndex < ActiveRecord::Migration[6.1]
  def up
    remove_index :master_policy_configurations, [:carrier_policy_type_id, :configurable_type, :configurable_id], name: "index_cpt_and_conf_on_mpc", unique: true
    add_index :master_policy_configurations, [:carrier_policy_type_id, :configurable_type, :configurable_id], name: "index_cpt_and_conf_on_mpc", unique: false
  end

  def down
    remove_index :master_policy_configurations, [:carrier_policy_type_id, :configurable_type, :configurable_id], name: "index_cpt_and_conf_on_mpc", unique: false
    add_index :master_policy_configurations, [:carrier_policy_type_id, :configurable_type, :configurable_id], name: "index_cpt_and_conf_on_mpc", unique: true
  end
end
