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
      t.references :carrier_policy_type, null: false, foreign_key: true
      t.references :configurable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
