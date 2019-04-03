class CreatePayments < ActiveRecord::Migration[5.2]
  def change
    create_table :payments do |t|
      t.boolean :active
      t.integer :status
      t.integer :amount
      t.integer :reason
      t.string :stripe_id, 
        index: { 
          :name => "stripe_payment", 
          :unique => true 
        }
      t.references :charge
      t.timestamps
    end
  end
end
