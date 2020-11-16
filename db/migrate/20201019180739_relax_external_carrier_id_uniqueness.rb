class RelaxExternalCarrierIdUniqueness < ActiveRecord::Migration[5.2]
  def up
    remove_index :carrier_insurable_profiles, :external_carrier_id
    add_index :carrier_insurable_profiles, [:carrier_id, :external_carrier_id], name: :carrier_external_carrier_id, unique: true
  end
  
  def down
    remove_index :carrier_insurable_profiles, :carrier_external_carrier_id
    add_index :carrier_insurable_profiles, :external_carrier_id, name: :external_carrier_id, unique: true
  end
end
