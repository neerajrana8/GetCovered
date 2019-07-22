class CreateCarrierPolicyTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :carrier_policy_types do |t|
      t.jsonb :policy_defaults, default: {
        coverage_limits: {},
        deductibles: {},
        options: {}
      }
      t.jsonb :application_fields, default: []
      t.jsonb :application_questions, default: []
      t.boolean :application_required, :null => false, :default => false
      t.references :carrier
      t.references :policy_type
      
      t.timestamps
    end
  end
end
