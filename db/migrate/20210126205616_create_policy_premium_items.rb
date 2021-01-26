class CreatePolicyPremiumItems < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_premium_items do |t|
      t.string :title               # a descriptive title to be attached to line items on invoices
      t.integer :category           # whether this is a fee or a premium or what
      t.boolean :amortized          # whether this is amortized
      t.boolean :external           # whether this is collected by means other than the internal stripe system
      t.boolean :preprocessed       # whether this is paid out up-front rather than as received
      t.integer :original_total_due # the total due originally, before modifications like prorations
      t.integer :total_due          # the total due
      t.integer :total_received     # the amount we've been paid so far
      t.integer :total_processed    # the amount we've fully processed as received (i.e. logged as commissions or whatever other logic we want)
      t.references :policy_premium, foreign_key: true
      t.references :recipient, polymorphic: true
      t.references :source, polymorphic: true, null: true

      t.timestamps
    end
  end
end
