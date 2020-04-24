class CreatePolicyGroups < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_groups do |t|
      t.string :number, index: { unique: true }
      t.date :effective_date
      t.date :expiration_date
      t.boolean :auto_renew, :null => false, :default => false
      t.date :last_renewed_on
      t.integer :renew_count
      t.integer :billing_status
      t.integer :billing_dispute_count
      t.date :billing_behind_since
      t.integer :cancellation_code
      t.string :cancellation_date_date
      t.integer :status
      t.datetime :status_changed_on
      t.integer :billing_dispute_status
      t.boolean :billing_enabled, :null => false, :default => false
      t.boolean :system_purchased, :null => false, :default => false
      t.boolean :serviceable, :null => false, :default => false
      t.boolean :has_outstanding_refund, :null => false, :default => false
      t.jsonb :system_data, default: {}
      t.date  :last_payment_date
      t.date  :next_payment_date
      t.boolean :policy_in_system
      t.boolean :auto_pay

      t.references :agency
      t.references :account
      t.references :carrier
      t.references :policy_type

      t.timestamps
    end
  end
end
