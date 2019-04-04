class CreateCharges < ActiveRecord::Migration[5.1]
  def change
    create_table :charges do |t|
      t.integer :status, default: 0
      t.string :status_information
      t.integer :refund_status, default: 0
      t.integer :payment_method, default: 0
      t.integer :amount_returned_via_dispute, default: 0
      t.integer :amount_refunded, default: 0
      t.integer :amount_lost_to_disputes, default: 0
      t.integer :amount_in_queued_refunds, default: 0
      t.integer :dispute_count, default: 0

      t.string :stripe_id,
        index: {
          name: 'charge_stripe_id'
        }
      t.references :invoice

      t.timestamps
    end
  end
end