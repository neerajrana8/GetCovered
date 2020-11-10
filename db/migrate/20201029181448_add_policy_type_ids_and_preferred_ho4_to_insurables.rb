class AddPolicyTypeIdsAndPreferredHo4ToInsurables < ActiveRecord::Migration[5.2]
  def up
    add_column :insurables, :policy_type_ids, :bigint, array: true, null: false, default: []
    add_column :insurables, :preferred_ho4, :boolean, null: false, default: false
    # update the preferred ho4 values
    ::Insurable.where(id: ::CarrierInsurableProfile.where(carrier_id: [1,5])
                                                   .where.not(external_carrier_id: nil)
                                                   .order("insurable_id").group("insurable_id").pluck("insurable_id")
                     ).update_all(preferred_ho4: true)
    # update the policy type ids
    puts "-- Determining policy type ids for all insurables; this requires a nasty query for each insurable unless you want to write the code to do it more efficiently, so this may take a while..."
    RefreshInsurablePolicyTypeIdsJob.perform_now(::Insurable.all)
    puts "-- Woot woot! We did it!!!"
    # create index
    add_index :insurables, :preferred_ho4
    add_index :insurables, :policy_type_ids, name: "insurable_ptids_gin_index", using: :gin
  end
  
  def down
    remove_column :insurables, :preferred_ho4
    remove_column :insurables, :policy_type_ids
  end
end
