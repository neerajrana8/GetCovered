class CreateExternalCharges < ActiveRecord::Migration[5.2]
  def change
    create_table :external_charges do |t|
      t.boolean :processed, null: false, default: false
      t.boolean :invoice_aware, null: false, default: false
      t.integer :status, null: false
      t.datetime :status_changed_at
      t.string :external_reference, null: false
      t.integer :amount, null: false
      t.datetime :collected_at, null: false
      t.references :invoice
      t.timestamps
    end
  end
end
