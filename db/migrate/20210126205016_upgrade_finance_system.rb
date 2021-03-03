class UpgradeFinanceSystem < ActiveRecord::Migration[5.2]
  def up
    # update CarrierPolicyType data
    add_column :carrier_policy_types, :premium_proration_calculation, :string, null: false, default: 'no_proration'
    add_column :carrier_policy_types, :premium_proration_refunds_allowed, :boolean, null: false, default: true
    CarrierPolicyType.where(premium_refundable: true).update_all(premium_proration_calculation: 'per_payment_term') # MOOSE WARNING: is this the best default?
    remove_column :carrier_policy_types, :premium_refundable
    
    # update BillingStrategy
    add_reference :billing_strategies, :collector, polymorphic: true, null: true
  
    # get rid of really old tables we don't even use anymore
    drop_table :payments
    drop_table :modifiers
    drop_table :commission_deductions
    drop_table :commissions
    drop_table :commission_strategies
  
    # archive old tables
    rename_table :policy_premium_fees, :archived_policy_premium_fees
    rename_table :line_items, :archived_line_items
    rename_table :invoices, :archived_invoices
    rename_table :charges, :archived_charges
    rename_table :refunds, :archived_refunds
    rename_table :disputes, :archived_disputes # MOOSE WARNING redo dispute
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
      # pending proration tracking
      t.integer :preproration_modifiers, null: false, default: 0        # how many LineItemReductions are active that might modify preproration_total_due # MOOSE WARNING validate
      t.boolean :proration_pending, null: false, default: false         # whether there is a proration waiting to go into effect when preproration_modifiers drops to 0 # MOOSE WARNING validate
      # refund and cancellation settings
      t.integer :proration_calculation, null: false                     # how to divide payment into chunks when prorating
      t.boolean :proration_refunds_allowed,  null: false                # whether to refund chunk that would have been cancelled if not already paid when prorating
      # commissions settings
      t.boolean :preprocessed                                           # whether this is paid out up-front rather than as received
      # associations
      t.references :policy_premium                                      # the PolicyPremium we belong to
      t.references :recipient, polymorphic: true                        # the CommissionStrategy/Agent/Carrier who receives the money
      t.references :collector, polymorphic: true                        # the Agency or Carrier who collects the money
      #t.references :collection_plan, polymorphic: true, null: true     # record indicating what the collector will pay off on their end (see model for details)
      t.references :fee, null: true                                     # the Fee this item corresponds to, if any
    end
    
    create_table :policy_premium_payment_term do |t|
      t.datetime :original_first_moment, null: false                    # the first moment of the term, before prorations
      t.datetime :original_last_moment, null: false                     # the last moment of the term, before prorations
      t.datetime :first_moment, null: false                             # the first moment of the term
      t.datetime :last_moment, null: false                              # the last moment of the term
      t.decimal  :unprorated_proportion, null: false, default: 1        # the proportion of this term that remains unprorated
      t.boolean  :prorated, null: false, default: false                 # whether this term has been prorated at all
      t.integer  :time_resolution, null: false, default: 0              # enum for how precise to be with times
      t.boolean  :cancelled, null: false, default: false                # whether this term has been entirely cancelled (i.e. prorated into nothingness)
      t.integer  :default_weight                                        # the default weight for policy_premium_item_payment_terms based on this payment term (i.e. the billing_strategy.new_business["payments"] value)
      t.string   :term_group                                            # used in case there are overlapping terms with different functionalities
      t.references :policy_premium
    end
    
    create_table :policy_premium_item_payment_term do |t|
      t.integer :weight, null: false                                    # the weight assigned to this payment term for calculating total due
      t.references :policy_premium_payment_term
      t.references :policy_premium_item
    end
  
    
    create_table :policy_premia do |t|
      # totals
      t.integer :total_premium, null: false, default: 0
      t.integer :total_fee, null: false, default: 0
      t.integer :total_tax, null: false, default: 0
      t.integer :total, null: false, default: 0
      # down payment settings
      t.boolean :first_payment_down_payment, null: false, default: false
      t.integer :first_payment_down_payment_amount_override
      # proration information
      t.boolean :prorated, null: false, default: false
      t.datetime :prorated_term_last_moment
      t.datetime :prorated_term_first_moment
      # miscellaneous
      t.timestamps
      t.string  :error_info
      # references
      t.references :policy_quote
      t.references :billing_strategy
      t.references :commission_strategy
      t.references :policy, null: true
    end
    
    create_table :line_items do |t|
      # basic details
      t.string      :title, null: false                                 # the title to display on the invoice
      t.boolean     :priced_in, null: false, default: false             # true if this line item has been taken into account in the invoice total (i.e. starts as false and gets set to true once invoice processes the addition)
      t.timestamps
      # payment tracking
      t.integer     :original_total_due,  null: false                   # the total due when this line item was created
      t.integer     :total_due, null: false                             # the total due now (i.e. original_total_due minus refunds plus increases)
      t.integer     :total_reducing, null: falsee, default: 0           # the amount subtracted from total_due by pending LineItemReductions
      t.integer     :total_received, null: false, default: 0            # the amount received towards payment of total_due
      
      t.integer     :preproration_total_due, null: false                # the amount due before any prorations MOOSE WARNING: no validations
      t.integer     :duplicatable_reduction_total, null: false, default: 0  # the total of all reductions with proration_interaction 'duplicated' MOOSE WARNING: no validations
      
      # references
      t.references  :chargeable, polymorphic: true                      # will be a PolicyPremiumItemTerm right now, but could be anything
      t.references  :invoice                                            # the invoice to which this LineItem belongs
    end
    
    create_table :invoices do |t|
      # basic info
      t.string      :number, null: false
      t.text        :description
      t.date        :available_date, null: false
      t.date        :due_date, null: false
      t.timestamps
      # state
      t.boolean     :external, null: false, default: false              # true if this is just a record of an invoice handled on a partner's server (i.e. we don't collect the payments)
      t.integer     :status, null: false                                # invoice status
      t.boolean     :under_review, null: false, default: false          # true if this invoice is under review due to a charge error. refunds are frozen during review (but charges aren't, since the charge that errored will still be counted as pending and absent from total_payable)
      t.integer     :pending_charge_count, null: false, default: 0      # how many charges are pending (i.e. not yet processed, doesn't necessarily mean in 'pending' status)
      t.integer     :pending_dispute_count, null: false, default: 0     
      t.jsonb       :error_info, null: false, default: []               # an array of error hashes representing charge problems that have put this invoice into under_review status
      t.boolean     :was_missed, null: false, default: false            # true if this invoice was ever missed
      t.datetime    :was_missed_at                                      # set to the first time this invoice was missed
      t.boolean     :autosend_status_change_notifications, null: false, # true to automatically send status notifications when status changes; change to false if manually switching statuses around a bunch temporarily
        default: true
      # payment tracking
      t.integer     :original_total_due, null: false                    # the total due when this invoice was created
      t.integer     :total_due, null: false                             # the total due now (taking refunds & newly added line items into account)
      t.integer     :total_reducing, null: falsee, default: 0           # the amount subtracted from total_due by pending LineItemReductions
      t.integer     :total_payable, null: false                         # the total that can be paid now (i.e. total_due - total_pending - total_received)
      t.integer     :total_pending, null: false, default: 0             # the total amount pending (i.e. the sum of charge.amount over all charges with processed: false)
      t.integer     :total_received, null: false, default: 0            # the total that has actually been received
      t.integer     :total_undistributable, null: false, default: 0     # if we receive a payment and the line items totals have somehow changed so that what we charged for has become less than the total, the extra is recorded here
      # disputes and refunds
      t.integer     :pending_dispute_total, null: false, default: 0
      t.integer     :pending_refund_total, null: false, default: 0
      t.integer     :total_refunded, null: false, default: 0
      t.integer     :total_lost_to_disputes, null: false, default: 0
      # associations
      t.references :invoiceable, polymorphic: true
      t.references :payer, polymorphic: true
      t.references :collector, polymorphic: true
    end
    
    create_table :stripe_charges do |t|
      t.boolean   :processed, null: false, default: false               # whether the charge has been handled by its invoice after success/failure
      t.boolean   :invoice_aware, null: false, default: false           # whether the invoice is aware of the charge's state
      t.integer   :status, null: false, default: 0                      # the status of the stripe charge
      t.datetime  :status_changed_at                                    # when the status was last changed
      t.integer   :amount, null: false                                  # the amount charged
      t.integer   :amount_refunded, null: false, default: 0             # the amount that has been refunded
      t.string    :source                                               # the payment source string provided
      t.string    :customer_stripe_id                                   # the customer stripe id, if any
      t.string    :description                                          # the description passed to stripe
      t.jsonb     :metadata                                             # the metadata passed to stripe
      t.string    :stripe_id                                            # the stripe id of the charge
      t.string    :error_info                                           # detailed English error info for dev access
      t.jsonb     :client_error                                         # I18n.t parameters, format { linear: [a,b,c,...], keyword: { a: :b, c: :d, ... } }
      t.timestamps
      t.references :invoice, null: true
    end

    create_table :disputes do |t|
      t.string    :stripe_id, null: false
      t.integer   :amount, null: false
      t.integer   :stripe_reason, null: false
      t.integer   :status, null: false
      t.boolean   :active, null: false, default: true
      t.timestamps
      t.references :stripe_charge
    end
    
    create_table :line_item_change do |t|
      t.integer     :field_changed, null: false                         # which field was changed (total_due or total_received)
      t.integer     :amount, null: false                                # the change to line_item.total_received (positive or negative)
      t.boolean     :handled, null: false, default: false               # whether a handler has handled this LIC (we could just use !lic.handler.nil?, but this is cleaner)
      t.references  :line_item                                          # the LineItem
      t.references  :reason, polymorphic: true                          # the reason for this change (a StripeCharge object, for example, or a LineItemReduction)
      t.references  :handler, polymorphic: true, null: true             # the CommissionItem that reflects this change, or other model that handled it
      t.timestamps
    end
    
    create_table :line_item_reduction do |t|
      t.string          :reason, null: false                            # String describing the reason for this reduction
      t.integer         :refundability, null: false                     # Enum for whether we can be refunded or only cancelled before payment
      t.integer         :proration_interaction, null: false, default: 0 # How we interact with any future prorations
      t.integer         :amount_interpretation, null: false, default: 0 # Whether "amount" represents amount to reduce by or maximum amount after reduction
      t.integer         :amount, null: false                            # The amount by which the line item total_due should be reduced
      t.integer         :amount_successful, null: false, default: 0     # The amount that actually ended up being reduced (if refunds_allowed, will be total_due_max_reduction; if not, it might be less)
      t.integer         :amount_refunded, null: false, default: 0
      t.boolean         :pending, null: false, default: true            # True iff this LIR hasn't yet been applied
      t.boolean         :processed, null: false, default: false         # True iff this LIR has completed all its work... MOOSE WARNING: is this needed???
      t.integer         :stripe_refund_reason                           # Optional enum field to specify a Stripe reason enum to provide for associated refunds; if nil, will use 'requested_by_customer' if any Stripe refunds are created
      t.timestamps
      t.references      :line_item
      t.references      :dispute, null: true                            # When refundability is 'dispute_resolution', we link to the relevant dispute here
      t.references      :refund, null: true                             # When this LIR results in a refund, we link to it here
    end
    
    create_table :refunds do |t|
      t.string    :refund_reasons, null: false, array: true, default: []# Array of strings describing the reasons for the refund
      t.integer   :amount, null: false , default: 0                     # How much to refund/return by dispute
      t.integer   :amount_refunded, null: false, default: 0             # How much actually was refunded
      t.integer   :amount_returned_by_dispute, null: false, default: 0  # How much actually was returned by dispute
      t.boolean   :complete, null: false, default: false                # Whether the refund process is complete
      t.references :invoice                                             # The invoice this refund applies to
    end
    
    create_table :stripe_refunds do |t|
      t.integer   :status, null: false, default: 0
      t.string    :full_reasons, null: false, array: true, default: []
      t.integer   :amount, null: false
      t.string    :stripe_id
      t.integer   :stripe_reason
      t.integer   :stripe_status
      t.string    :failure_reason
      t.string    :receipt_number
      t.string    :error_message
      t.timestamps
      t.references :refund
      t.references :stripe_charge
    end
    
    
    create_table :commissions do |t|
      # General data
      t.integer       :status, null: false                              # The status of the commission. Only one commission per recipient can be 'collating', and barring weird errors that commission will never become non-collating.
      t.integer       :total, null: false, default: 0                   # The total to be paid
      t.boolean       :true_negative_payout, null: false, default: false# True if the total is negative and we want to ACTUALLY refund it instead of just creating a 'paid' commission for it and rolling the debt over to the next commission
      t.integer       :payout_method, null: false, default: 0           # The method of actually paying the money ('manual' or 'stripe' for now)
      t.string        :error_info                                       # If status is 'payout_error', this will contain a description of what went wrong
      t.timestamps
      t.references    :recipient, polymorphic: true                     # Who gets this payout?
      # Payout data
      t.string        :stripe_transfer_id                               # For stripe payouts, will contian the id of the Stripe::Transfer object created
      t.jsonb         :payout_data                                      # Optional data stored about the payout process
      t.text          :payout_notes                                     # Optional text notes about the payout process
      t.datetime      :approved_at, null: true                          # When it was approved
      t.datetime      :marked_paid_at, null: true                       # When it was marked paid
      t.references    :approved_by, null: true                          # The superadmin who approved it
      t.references    :marked_paid_by, null: true                       # The superadmin who marked it paid
    end
    
    create_table :commission_items do |t|
      t.integer       :amount, null: false                              # The amount of money to pay out for this item. May be negative.
      t.timestamps
      t.references    :commission                                       # The commission on which this item is listed.
      t.references    :commissionable, polymorphic: true                # The thing this item is being paid for. Generally will be a PolicyPremiumItem.
      t.references    :policy, null: true                               # Optional direct reference to the Policy this item applies to, if it applies to one
    end
    
    create_table :commission_strategies do |t|
      t.string        :title, null: false                               # An easily-identifiable title
      t.decimal       :percentage, null: false, precision: 5, scale: 2  # The percentage of the total that goes to this fellow
      t.timestamps
      t.references    :recipient, polymorphic: true                     # He who receives the money
      t.references    :commission_strategy, optional: true              # The parent commission strategy
    end
  
  end
  
  def down
  end
end
