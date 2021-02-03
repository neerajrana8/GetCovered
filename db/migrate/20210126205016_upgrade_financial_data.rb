class ArchiveOldFinancialData < ActiveRecord::Migration[5.2]
  def up
    # archive old tables
    rename_table :policy_premium_fees, :archived_policy_premium_fees
    rename_table :line_items, :archived_line_items
    rename_table :invoices, :archived_invoices
    rename_table :policy_premia, :archived_policy_premia

    # create replacement tables
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
      t.boolean :all_received, null: false, default: false              # whether we've received the full total (for efficient queries)
      t.boolean :all_processed: null: false, default: false             # whether we've processed the full amount received (for efficient queries)
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
  
    create_table :line_items do |t|
      # basic details
      t.string      :title
      t.timestamps
      # payment tracking
      t.integer     :original_total_due,  null: false
      t.integer     :total_due, null: false
      t.integer     :total_received, null: false, default: 0
      t.integer     :total_processed, null: false, default: 0
      t.boolean     :all_received, null: false, default: false
      t.boolean     :all_processed: null: false, default: false
      t.references  :invoice, index: true
      # details about what this line item is for
      t.datetime :term_first_date
      t.datetime :term_last_date
      t.references  :policy_premium_item, index: true
    end
    
    create_table :invoices do |t|
      # basic info
      t.string :number
      t.text :description
      t.date :due_date
      t.timestamps
      # state
      t.boolean :external, null: false, default: false
      t.integer :status
      t.datetime :status_changed
      t.boolean :was_missed, null: false, default: false
      # payment tracking
      t.integer :original_total_due, null: false
      t.integer :total_due, null: false
      t.integer :total_received, null: false, default: 0
      t.boolean :all_processed, null: false, default: false
      # disputes and refunds
      t.integer :pending_dispute_total, null: false, default: 0
      t.integer :pending_refund_total, null: false, default: 0
      t.integer :total_refunded, null: false, default: 0
      t.integer :total_lost_to_disputes, null: false, default: 0
      # associations
      t.references :invoiceable, polymorphic: true
      t.references :payer, polymorphic: true
    end
  
    #add_reference :line_items, :policy_premium_item, index: true, null: false
    #add_column :line_items, :original_total_due # set to price
    #add_column :line_items, :total_due           # set to price - proration_reduction
    #add_column :line_items, :total_received # set to collected
    #add_column :line_items, :total_processed # set to 0
  
  end
  
  def down
  end
end
