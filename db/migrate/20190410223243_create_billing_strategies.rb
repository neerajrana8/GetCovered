class CreateBillingStrategies < ActiveRecord::Migration[5.2]
  def change
    create_table :billing_strategies do |t|
      t.string :title
      t.string :slug
      t.boolean :enabled, :null => false, :default => false
      t.jsonb :new_business, default: {        
          remainder_added_to_deposit: true,
          payments_per_term: 1,
          payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
      t.jsonb :renewal
#      t.jsonb :fees, default: [
#        { per_payment: true, flat: true, amount: 0, title: "Service Fee" }
#      ]
      t.boolean :locked, :null => false, :default => false
      t.references :agency
      t.references :carrier
      t.references :policy_type

      t.timestamps
    end
  end
end
