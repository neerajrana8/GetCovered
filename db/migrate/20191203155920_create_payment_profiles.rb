class CreatePaymentProfiles < ActiveRecord::Migration[5.2]
  def change
    create_table :payment_profiles do |t|
      t.string :source_id
      t.integer :source_type
      t.string :fingerprint
      t.boolean :default_profile, default: false
      t.boolean :active
      t.boolean :verified
      t.references :user, index: true, foreign_key: true

      t.timestamps
    end
  end
end
