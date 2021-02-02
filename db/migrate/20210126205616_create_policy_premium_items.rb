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
      t.references :policy_premium                                      # the PolicyPremium we belong to
      t.references :recipient, polymorphic: true                        # the CommissionStrategy/Agent/Carrier who receives the money
      t.references :collector, polymorphic: true                        # the Agency or Carrier who collects the money
      t.references :collection_plan, polymorphic: true, null: true      # record indicating what the collector will pay off on their end (see model for details)
      t.references :fee, null: true                                     # the Fee this item corresponds to, if any

      t.timestamps
    end
  end
end
