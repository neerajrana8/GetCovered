class CreatePolicies < ActiveRecord::Migration[5.2]
  def change
    create_table :policies do |t|
      t.string :number
      t.date :effective_date
      t.date :expiration
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
      t.references :agency
      t.references :account
      t.references :carrier
      t.references :policy_type
      t.references :billing_profie

      t.timestamps
    end
  end
end
