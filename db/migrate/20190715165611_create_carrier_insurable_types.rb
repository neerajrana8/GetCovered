class CreateCarrierInsurableTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :carrier_insurable_types do |t|
      t.jsonb :profile_attributes, default: {}
      t.jsonb :profile_data, default: {}
      t.boolean :enabled, :null => false, :default => false
      t.references :carrier
      t.references :insurable_type

      t.timestamps
    end
  end
end
