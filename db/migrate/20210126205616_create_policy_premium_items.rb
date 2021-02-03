class CreatePolicyPremiumItems < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_premium_items do |t|
      # what this is and how to charge for it
      t.string :title                                                   # a descriptive title to be attached to line items on invoices
      t.integer :category                                               # whether this is a fee or a premium or what
      t.integer :amortization                                           # how this payment should be spread among invoices
      t.integer :amortization_plan, array: true                         # amortization weighted breakdown
      t.integer :rounding_error_distribution, default: 0                # how to distribute rounding error
      t.timestamps                                                      # timestamps
      # payment tracking
      t.integer :original_total_due, null: false                        # the total due originally, before any modifications
      t.integer :total_due, null: false                                 # the total due
      t.integer :total_received, null: false                            # the amount we've been paid so far
      t.integer :total_processed, null: false                           # the amount we've fully processed as received (i.e. logged as commissions or whatever other logic we want)
      # refund and cancellation settings
      t.integer :proration_calculation, default: 0                      # how to divide payment into chunks when prorating
      # commissions settings
      t.boolean :preprocessed                                           # whether this is paid out up-front rather than as received
      # associations
      t.references :policy_premium                                      # the PolicyPremium we belong to
      t.references :recipient, polymorphic: true                        # the CommissionStrategy/Agent/Carrier who receives the money
      t.references :collector, polymorphic: true                        # the Agency or Carrier who collects the money
      #t.references :collection_plan, polymorphic: true, null: true      # record indicating what the collector will pay off on their end (see model for details)
      t.references :fee, null: true                                     # the Fee this item corresponds to, if any
    end
  end
end
