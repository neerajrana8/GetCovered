class CreateCarrierAgencies < ActiveRecord::Migration[5.2]
  def change
    create_table :carrier_agencies do |t|
      t.string :external_carrier_id
      t.references :carrier
      t.references :agency

      t.timestamps
    end
    
    add_index :carrier_agencies, :external_carrier_id, unique: true
  end
end
