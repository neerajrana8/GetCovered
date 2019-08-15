class CreatePolicyRates < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_rates do |t|
      t.references :policy
      t.references :policy_quote
      t.references :insurable_rate

      t.timestamps
    end
  end
end
