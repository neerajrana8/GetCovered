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
      t.references    :commission_strategy, null: true                  # Temporarily nullable for data entry
    end
    
    # add CS field to Carrier
    add_reference :carriers, :commission_strategy, null: true
    
    # add CS field to CarrierPolicyType
    add_reference :carrier_policy_types, :commission_strategy, null: true  # Default commission strategy as parent to everybody
    
    # create CAPTs
    params = ["carrier_agencies.carrier_id", "carrier_agencies.agency_id", "policy_type_id"]
    CarrierAgencyAuthorization.includes(:carrier_agency).references(:carrier_agencies).order(*params).group(*params).pluck(*params)
                              .each do |trid| # tri-id... hahaha... ha... ha......
      capt = ::CarrierAgencyPolicyType.new(
        carrier_id: trid[0],
        agency_id: trid[1],
        policy_type_id: trid[2]
      )
      capt.callbacks_disabled = true
      capt.save!
    end
  end
  
  def down
    remove_reference :carriers, :commission_strategy
    remove_reference :carrier_policy_types, :commission_strategy
    drop_table :carrier_agency_policy_types
    drop_table :commission_strategies
    rename_table :archived_commission_strategies, :commission_strategies
  end
end
