class UpgradeFinanceSystem < ActiveRecord::Migration[5.2]
  def up
  
    # update CarrierAgencyAuthorization
    add_reference :carrier_agency_authorizations, :commission_strategy, null: true # WARNING: set null: false in a second migration after data entry
    
    # upgrade CommissionStrategy
    rename_table :commission_strategies, :archived_commission_strategies
    
    create_table :commission_strategies do |t|
      t.string        :title, null: false                               # An easily-identifiable title
      t.decimal       :percentage, null: false, precision: 5, scale: 2  # The percentage of the total that goes to this fellow
      t.timestamps
      t.references    :recipient, polymorphic: true                     # He who receives the money
      t.references    :commission_strategy, optional: true              # The parent commission strategy
    end
  
  end
  
  def down
    drop_table :commission_strategies
    rename_table :archived_commission_strategies, :commission_strategies
    remove_reference :carrier_agency_authorizations, :commission_strategy
  end
end
