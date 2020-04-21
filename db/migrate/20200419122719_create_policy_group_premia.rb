class CreatePolicyGroupPremia < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_group_premia do |t|

      t.integer :base, :default => 0
      t.integer :taxes, :default => 0
      t.integer :total_fees, :default => 0
      t.integer :total, :default => 0
      t.integer :estimate
      t.integer :calculation_base, :default => 0
      t.integer :deposit_fees,:default => 0
      t.integer :amortized_fees, :default => 0
      t.integer :special_premium, :integer, :default => 0
      t.boolean :include_special_premium, :boolean, :default => false
      t.integer :carrier_base, :default => 0
      t.integer :unearned_premium, :default => 0

      t.boolean :enabled, :null => false, :default => false
      t.datetime :enabled_changed

      t.references :policy_group_quote, index: true
      t.references :billing_strategy
      t.references :commission_strategy
      t.timestamps
    end
  end
end
