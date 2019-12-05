class AddExternalCarrierIdToCarrierInsurableProfile < ActiveRecord::Migration[5.2]
  def change
    add_column :carrier_insurable_profiles, :external_carrier_id, :string
    add_index :carrier_insurable_profiles, :external_carrier_id, unique: true
  end
end
