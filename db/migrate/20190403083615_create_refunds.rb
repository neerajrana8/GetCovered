class CreateRefunds < ActiveRecord::Migration[5.2]
  def change
    create_table :refunds do |t|
      # stripe information (strip 'stripe_' prefix when needed and '_id' from stripe_charge_id)
      t.string :stripe_id,
        index: {
          name: 'refund_stripe_id'
        }
      t.integer :amount
      t.string :currency
      t.string :failure_reason
      t.integer :stripe_reason
      t.string :receipt_number
      t.integer :stripe_status
      # local information
      t.integer :status,
        index: {
          name: 'refund_status'
        }
      t.string :full_reason
      t.string :error_message
      t.integer :amount_returned_via_dispute, default: 0
      t.references :charge

      t.timestamps
    end
  end
end
