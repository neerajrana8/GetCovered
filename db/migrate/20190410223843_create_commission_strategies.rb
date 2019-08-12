class CreateCommissionStrategies < ActiveRecord::Migration[5.2]
  def change
    create_table :commission_strategies do |t|
	    t.string :title, :null => false
      t.integer :amount, :null => false, :default => 10
      t.integer :type, :null => false, :default => 0
      t.integer :fulfillment_schedule, :null => false, :default => 0
      t.boolean :amortize, :null => false, :default => false
      t.boolean :per_payment, :null => false, :default => false
      t.boolean :enabled, :null => false, :default => false
      t.boolean :locked, :null => false, :default => false
      t.integer :house_override, :null => false, :default => 10
      t.integer :override_type, :null => false, :default => 0
      t.references :carrier
      t.references :policy_type
      t.references :commissionable, polymorphic: true, 
                                    index: { name: 'index_strategy_on_type_and_id' }

      t.timestamps
    end
  end
end
