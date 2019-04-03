class CreateDisputes < ActiveRecord::Migration[5.2]
  def change
    create_table :disputes do |t|
      # stripe information (strip 'stripe_' prefix when needed and '_id' from stripe_charge_id)
      t.string :stripe_id,
        index: {
          name: 'dispute_stripe_id'
        }
      t.integer :amount
      t.integer :reason
      t.integer :status,
        index: {
          name: 'dispute_status'
        }
      # local information
      t.boolean :active
      t.references :charge

      t.timestamps
    end
  end
end
