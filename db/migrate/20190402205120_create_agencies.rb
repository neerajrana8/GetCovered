class CreateAgencies < ActiveRecord::Migration[5.2]
  def change
    create_table :agencies do |t|
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
      t.boolean :master_agency, :null => false, :default => false
      t.jsonb :contact_info, :default => {}
      t.jsonb :settings, :default => {}

      t.timestamps
    end
    add_index :agencies, :stripe_id, unique: true
    add_index :agencies, :call_sign, unique: true
  end
end
