class CreatePolicyPremiumFees < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_premium_fees do |t|
      t.references :policy_premium
      t.references :fee

      t.timestamps
    end
  end
end
