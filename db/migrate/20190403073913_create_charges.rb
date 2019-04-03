class CreateCharges < ActiveRecord::Migration[5.1]
  def change
    create_table :charges do |t|
      t.integer :status
      t.integer :status_information
      t.integer :refund_status
      t.integer :payment_method
      t.integer :amount_returned_via_dispute
      t.integer :amount_refunded
      t.integer :amount_lost_to_disputes
      t.integer :amount_in_queued_refunds
      t.integer :dispute_count

      t.string :stripe_id,
        index: {
          name: 'charge_stripe_id'
        }
      t.references :invoice

      t.timestamps
    end
  end
end
