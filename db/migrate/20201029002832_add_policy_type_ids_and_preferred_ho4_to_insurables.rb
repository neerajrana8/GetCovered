class AddPolicyTypeIdsAndPreferredHo4ToInsurables < ActiveRecord::Migration[5.2]
  def up
    add_column :insurables, :policy_type_ids, :bigint, array: true, null: false, default: []
    add_column :insurables, :preferred_ho4, :boolean, null: false, default: false
    
    ::Insurable.where(id: ::CarrierInsurableProfile.where(carrier_id: 5, insurable_id: nil)
                                                 .where.not(external_carrier_id: nil)
                                                 .order("insurable_id").group("insurable_id").pluck("insurable_id")
                   ).update_all(preferred_ho4: true)
  end
  
  def down
    remove_column :insurables, :preferred_ho4
    remove_column :insurables, :policy_type_ids
  end
end
