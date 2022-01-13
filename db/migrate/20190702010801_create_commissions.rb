class CreateCommissions < ActiveRecord::Migration[5.2]
  def change
    create_table :commissions do |t|
      t.integer :amount
      t.integer :deductions
      t.integer :total
      t.boolean :approved
      t.date :distributes
      t.boolean :paid
      t.string :stripe_transaction_id
      t.references :policy_premium
      t.references :commission_strategy
      t.references :commissionable, polymorphic: true, index: { name: "index_commissions_on_commissionable_type_and_commissionable_id" }

      t.timestamps
    end
  end
end
