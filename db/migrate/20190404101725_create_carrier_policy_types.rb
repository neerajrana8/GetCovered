class CreateCarrierPolicyTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :carrier_policy_types do |t|
      t.jsonb :defaults, default: {
        coverage_limits: {},
        deductibles: {},
        options: {}
      }
      t.references :carrier
      t.references :policy_type
      
      t.timestamps
    end
  end
end
