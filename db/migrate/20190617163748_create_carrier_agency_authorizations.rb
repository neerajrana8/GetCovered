class CreateCarrierAgencyAuthorizations < ActiveRecord::Migration[5.2]
  def change
    create_table :carrier_agency_authorizations do |t|
      t.integer :state
      t.boolean :available, :null => false, :default => false
      t.jsonb :zip_code_blacklist, default: {}
      t.references :carrier_agency
      t.references :policy_type
      t.references :agency

      t.timestamps
    end
  end
end
