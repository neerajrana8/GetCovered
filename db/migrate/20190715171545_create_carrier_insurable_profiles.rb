class CreateCarrierInsurableProfiles < ActiveRecord::Migration[5.2]
  def change
    create_table :carrier_insurable_profiles do |t|
      t.jsonb :traits, default: {}
      t.jsonb :data, default: {}
      t.references :carrier
      t.references :insurable

      t.timestamps
    end
  end
end
