class CreateMasterPolicyConfigurations < ActiveRecord::Migration[6.1]
  def change
    create_table :master_policy_configurations do |t|
      t.integer :program_type, :default => 0
      t.integer :grace_period, :default => 0
      t.string :integration_charge_code
      t.boolean :prorate_charges, :default => false
      t.boolean :auto_post_charges, :default => true
      t.boolean :consolidate_billing, :default => true
      t.datetime :program_start_date
      t.integer :program_delay, :default => 0
      t.integer :placement_cost, :default => 0
      t.integer :force_placement_cost
      t.references :carrier_policy_type, null: false, index: false
      t.references :configurable, polymorphic: true, null: false

      t.timestamps
    end
    add_index :master_policy_configurations, [:carrier_policy_type_id, :configurable_type, :configurable_id], name: "index_cpt_and_conf_on_mpc", unique: true
  end
end
