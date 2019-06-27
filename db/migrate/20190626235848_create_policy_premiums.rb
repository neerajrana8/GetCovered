class CreatePolicyPremiums < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_premia do |t|
      t.integer :base, :default => 0
      t.integer :taxes, :default => 0
      t.integer :total_fees, :default => 0
      t.integer :total, :default => 0
      t.boolean :enabled, :null => false, :default => false
      t.datetime :enabled_changed
      t.references :policy_quote
      t.references :policy

      t.timestamps
    end
  end
end
