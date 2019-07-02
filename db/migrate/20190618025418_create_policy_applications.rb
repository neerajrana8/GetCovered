class CreatePolicyApplications < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_applications do |t|
      t.string :reference
      t.string :external_reference
      t.date :effective_date
      t.date :expiration_date
      t.integer :status, :null => false, :default => 0
      t.datetime :status_updated_on
      t.jsonb :fields, default: {}
      t.references :carrier
      t.references :policy_type
      t.references :agency
      t.references :account
      t.references :policy

      t.timestamps
    end
  end
end
