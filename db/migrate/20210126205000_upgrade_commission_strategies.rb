class UpgradeCommissionStrategies< ActiveRecord::Migration[5.2]
  def up
    # upgrade CommissionStrategy
    rename_table :commission_strategies, :archived_commission_strategies
    
    create_table :commission_strategies do |t|
      t.string        :title, null: false                               # An easily-identifiable title
      t.decimal       :percentage, null: false, precision: 5, scale: 2  # The percentage of the total that goes to this fellow
      t.timestamps
      t.references    :recipient, polymorphic: true                     # He who receives the money
      t.references    :commission_strategy, optional: true              # The parent commission strategy
    end
    
    # add a CarrierAgencyPolicyType model to store the CS
    create_table :carrier_agency_policy_types do |t|
      t.references    :carrier
      t.references    :agency
      t.references    :policy_type
      t.references    :commission_strategy, null: true                  # Temporarily null: true for data entry
    end
  
  end
  
  def down
    drop_table :carrier_agency_policy_types
    drop_table :commission_strategies
    rename_table :archived_commission_strategies, :commission_strategies
  end
end
