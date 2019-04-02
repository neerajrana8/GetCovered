class CreateAccounts < ActiveRecord::Migration[5.2]
  def change
    create_table :accounts do |t|
      t.string :title
      t.string :slug
      t.string :call_sign
      t.boolean :enabled, :null => false, :default => false
      t.boolean :whitelabel, :null => false, :default => false
      t.boolean :tos_accepted, :null => false, :default => false
      t.datetime :tos_accepted_at
      t.string :tos_acceptance_ip
      t.boolean :verified, :null => false, :default => false
      t.string :stripe_id
      t.jsonb :contact_info, :default => {}
      t.jsonb :settings, :default => {}
      t.references :staff
      t.references :agency

      t.timestamps
    end
    add_index :accounts, :stripe_id, unique: true
    add_index :accounts, :call_sign, unique: true
  end
end
