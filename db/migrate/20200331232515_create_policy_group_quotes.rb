class CreatePolicyGroupQuotes < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_group_quotes do |t|
      t.string :reference
      t.string :external_reference
      t.integer :status
      t.datetime :status_updated_on
      t.integer :premium
      t.integer :tax
      t.integer :est_fees
      t.integer :total_premium
      t.references :agency
      t.references :account
      t.references :policy_application_group

      t.timestamps
    end
  end
end
