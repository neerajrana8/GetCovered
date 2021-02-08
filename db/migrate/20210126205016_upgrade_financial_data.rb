class ArchiveOldFinancialData < ActiveRecord::Migration[5.2]
  def up
    # update CarrierPolicyType data
    add_column :carrier_policy_types, :premium_proration_calculation, :string, null: false, default: 'no_proration'
    add_column :carrier_policy_types, :premium_proration_refunds_allowed, :boolean, null: false, default: true
    CarrierPolicyType.where(premium_refundable: true).update_all(premium_proration_calculation: 'per_payment_term') # MOOSE WARNING: is this the best default?
    remove_column :carrier_policy_types, :premium_refundable
    
    # update BillingStrategy
    add_reference :billing_strategies, :collector, foreign_key: false, polymorphic: true
  
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
      t.integer :rounding_error_distribution, default: 0                # how to distribute rounding error
      t.timestamps                                                      # timestamps
      # payment tracking
      t.integer :original_total_due, null: false                        # the total due originally, before any modifications
      t.integer :total_due, null: false                                 # the total due
      t.integer :total_received, null: false, default: 0                # the amount we've been paid so far
      t.integer :total_processed, null: false, default: 0               # the amount we've fully processed as received (i.e. logged as commissions or whatever other logic we want)
      t.boolean :all_received, null: false, default: false              # whether we've received the full total (for efficient queries)
      t.boolean :all_processed: null: false, default: false             # whether we've processed the full amount received (for efficient queries)
      # refund and cancellation settings
      t.integer :proration_calculation, null: false                     # how to divide payment into chunks when prorating
      t.boolean :proration_refunds_allowed,  null: false                # whether to refund chunk that would have been cancelled if not already paid when prorating
      # commissions settings
      t.boolean :preprocessed                                           # whether this is paid out up-front rather than as received
      # associations
      t.references :policy_premium, foreign_key: false                  # the PolicyPremium we belong to
      t.references :recipient, foreign_key: false, polymorphic: true    # the CommissionStrategy/Agent/Carrier who receives the money
      t.references :collector, foreign_key: false, polymorphic: true   # the Agency or Carrier who collects the money
      #t.references :collection_plan, polymorphic: true, null: true     # record indicating what the collector will pay off on their end (see model for details)
      t.references :fee, null: true                                     # the Fee this item corresponds to, if any
    end
    
    
    create_table :policy_premium_payment_term do |t|
      t.datetime :original_first_moment, null: false                    # the first moment of the term, before prorations
      t.datetime :original_last_moment, null: false                     # the last moment of the term, before prorations
      t.datetime :first_moment, null: false                             # the first moment of the term
      t.datetime :last_moment, null: false                              # the last moment of the term
      t.integer  :time_resolution, null: false, default: 0              # enum for how precise to be with times
      t.boolean  :cancelled, null: false, default: false                # whether this term has been entirely cancelled (i.e. prorated into nothingness)
      t.integer  :default_weight                                        # the default weight for policy_premium_item_payment_terms based on this payment term (i.e. the billing_strategy.new_business["payments"] value)
      t.string   :term_group                                            # used in case there are overlapping terms with different functionalities
      t.references :policy_premium, foreign_key: false
    end
    
    create_table :policy_premium_item_payment_term do |t|
      t.integer :weight, null: false                                    # the weight assigned to this payment term for calculating total due
      t.integer :original_total_due                                     # the amount due before any prorations MOOSE WARNING: no validations
      t.references :policy_premium_payment_term, foreign_key: false
      t.references :policy_premium_item, foreign_key: false
    end
  
    create_table :line_items do |t|
      # basic details
      t.string      :title, null: false
      t.boolean     :priced_in, null: false, default: false
      t.timestamps
      # payment tracking
      t.integer     :original_total_due,  null: false
      t.integer     :total_due, null: false
      t.integer     :total_received, null: false, default: 0
      t.integer     :total_processed, null: false, default: 0
      t.boolean     :all_received, null: false, default: false
      t.boolean     :all_processed: null: false, default: false
      t.references  :invoice, foreign_key: false
      # details about what this line item is for
      t.references :chargeable, foreign_key: false, polymorphic: true    # will be a PolicyPremiumItemTerm for now
    end
    
    create_table :policy_premia do |t|
      # totals
      t.integer :total_premium, null: false, default: 0
      t.integer :total_special_premium, null: false, default: 0
      t.integer :total_fee, null: false, default: 0
      t.integer :total_tax, null: false, default: 0
      t.integer :total, null: false, default: 0
      # down payment settings
      t.boolean :first_payment_down_payment, null: false, default: false
      t.integer :first_payment_down_payment_amount_override
      # miscellaneous
      t.timestamps
      t.string  :error_info
      # references
      t.references :policy_quote, foreign_key: false
      t.references :billing_strategy, foreign_key: false
      t.references :commission_strategy, foreign_key: false
      
  ##### MOOSE WARNING below is old schema for reference ############
      
      
    t.integer "base", default: 0
    t.integer "taxes", default: 0
    t.integer "total_fees", default: 0
    t.integer "total", default: 0
    t.boolean "enabled", default: false, null: false
    t.datetime "enabled_changed"
    t.bigint "policy_quote_id"
    t.bigint "policy_id"
    t.bigint "billing_strategy_id"
    t.bigint "commission_strategy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "estimate"
    t.integer "calculation_base", default: 0
    t.integer "deposit_fees", default: 0
    t.integer "amortized_fees", default: 0
    t.integer "carrier_base", default: 0
    t.integer "special_premium", default: 0
    t.boolean "include_special_premium", default: false
    t.integer "unearned_premium", default: 0
    t.boolean "only_fees_internal", default: false
    t.integer "external_fees", default: 0
      
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
      t.references :invoiceable, foreign_key: false, polymorphic: true
      t.references :payer, foreign_key: false, polymorphic: true
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
