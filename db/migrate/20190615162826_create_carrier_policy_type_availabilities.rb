class CreateCarrierPolicyTypeAvailabilities < ActiveRecord::Migration[5.2]
  def change
    create_table :carrier_policy_type_availabilities do |t|
      t.integer :state
      t.boolean :available, :null => false, :default => false
      t.jsonb :zip_code_blacklist, default: {}
      t.references :carrier_policy_type, index: { name: 'index_carrier_policy_availability' }

      t.timestamps
    end
  end
end
