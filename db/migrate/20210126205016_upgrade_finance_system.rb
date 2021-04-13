class UpgradeFinanceSystem < ActiveRecord::Migration[5.2]
  def up
    # remove nullability of certain commission strategy entries (they were temporarily null in the commission strategy branch for data entry purposes only)
    change_column_null :carrier_agency_policy_types, :commission_strategy_id, false
    change_column_null :carrier_policy_types, :commission_strategy_id, false
    
    # update CarrierPolicyType data
    add_column :carrier_policy_types, :premium_proration_calculation, :string, null: false, default: 'per_payment_term'
    add_column :carrier_policy_types, :premium_proration_refunds_allowed, :boolean, null: false, default: true
    CarrierPolicyType.where(premium_refundable: true).update_all(premium_proration_calculation: 'per_payment_term', premium_proration_refunds_allowed: true)
    CarrierPolicyType.where(premium_refundable: false).update_all(premium_proration_calculation: 'per_payment_term', premium_proration_refunds_allowed: false)
    remove_column :carrier_policy_types, :premium_refundable
    add_reference :carrier_agency_policy_types, :collector, polymorphic: true, null: true,
      index: { name: 'index_capt_on_collector' }
    
    # update Policy
    add_column :policies, :marked_for_cancellation, :boolean, null: false, default: true
    add_column :policies, :marked_for_cancellation_info, :string
    add_column :policies, :marked_cancellation_time, :datetime
    add_column :policies, :marked_cancellation_reason, :string
    
    # give PA an internal error message
    add_column :policy_applications, :internal_error_message, :string
  
    # get rid of really old tables we don't even use anymore
    drop_table :payments
    drop_table :modifiers
  
    # archive old tables
    to_archive = ['Charge', 'Commission', 'CommissionDeduction', 'CommissionStrategy',
                  'Dispute', 'Invoice', 'LineItem', 'PolicyPremium',
                  'PolicyPremiumFee', 'Refund'
                 ]
    rename_table :charges, :archived_charges
    rename_index :commissions, "index_commissions_on_commissionable_type_and_commissionable_id", "index_archived_commissions_on_commissionable"
    rename_table :commissions, :archived_commissions
    rename_index :commission_deductions, "index_commission_deductions_on_deductee_type_and_deductee_id", "index_craptastic_garbage_why_is_there_a_length_limit_ugh"
    rename_table :commission_deductions, :archived_commission_deductions
    rename_table :disputes, :archived_disputes
    rename_table :invoices, :archived_invoices
    rename_table :line_items, :archived_line_items
    rename_table :policy_premia, :archived_policy_premia
    rename_table :policy_premium_fees, :archived_policy_premium_fees
    rename_table :refunds, :archived_refunds
    ::History.where(recordable_type: to_archive).each{|h| h.update_columns(recordable_type: "Archived#{to_archive}") }
    {
      'Commission' => ['commissionable'],
      'CommissionDeduction' => ['deductee'],
      'CommissionStrategy' => ['commissionable'],
      'Invoice' => ['invoiceable', 'payer']
    }.each do |model, polymorphics|
      polymorphics.each do |poly|
        to_archive.each do |tarch|
          "Archived#{model}".constantize.where("#{poly}_type".to_sym => tarch).update_all("#{poly}_type".to_sym => "Archived#{tarch}")
        end
      end
    end
    
    
    # create replacement tables
    
    create_table :policy_premium_items do |t|
      # what this is and how to charge for it
      t.string  :title, null: false                                     # a descriptive title to be attached to line items on invoices
      t.integer :category, null: false                                  # whether this is a fee or a premium or what
      t.integer :rounding_error_distribution, default: 0                # how to distribute rounding error
      t.timestamps                                                      # timestamps
      # payment tracking
      t.integer :original_total_due, null: false                        # the total due originally, before any modifications
      t.integer :total_due, null: false                                 # the total due
      t.integer :total_received, null: false, default: 0                # the amount we've been paid so far
      t.integer :total_processed, null: false, default: 0               # the amount we've fully processed as received (i.e. logged as commissions or whatever other logic we want)
      t.boolean :all_received, null: false, default: false              # whether we've received the full total (for efficient queries)
      t.boolean :all_processed, null: false, default: false             # whether we've processed the full amount received (for efficient queries)
      # pending proration tracking
      t.integer :preproration_modifiers, null: false, default: 0        # how many LineItemReductions are active that might modify preproration_total_due # MOOSE WARNING validate
      t.boolean :proration_pending, null: false, default: false         # whether there is a proration waiting to go into effect when preproration_modifiers drops to 0 # MOOSE WARNING validate
      # refund and cancellation settings
      t.integer :proration_calculation, null: false                     # how to divide payment into chunks when prorating
      t.boolean :proration_refunds_allowed,  null: false                # whether to refund chunk that would have been cancelled if not already paid when prorating
      # commissions settings
      t.integer :commission_calculation, null: false, default: 0        # how to calculate commission payouts (default is to pay out proportionally for each payment/refund based on a fixed expected total due)
      t.integer :commission_creation_delay_hours                        # when commission_calculation is 'group_by_transaction', we wait this many hours before creating a commission item if no other transaction occurs first
      # associations
      t.references :policy_premium                                      # the PolicyPremium we belong to
      t.references :recipient, polymorphic: true                        # the CommissionStrategy/Agent/Carrier who receives the money
      t.references :collector, polymorphic: true                        # the Agency or Carrier who collects the money
      t.references :collection_plan, polymorphic: true, null: true,     # record indicating what the collector will pay off on their end (see model for details)
        index: { name: 'index_policy_premium_items_on_cp' }
      t.references :fee, null: true                                     # the Fee this item corresponds to, if any
    end
    
    create_table :policy_premium_payment_terms do |t|
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
      t.date     :invoice_available_date_override                       # used in case we need to provide an override to the default invoice available date calculation
      t.date     :invoice_due_date_override                             # used in case we need to provide an override to the defailt invoice due date calculation
      t.timestamps
      t.references :policy_premium
    end
    
    create_table :policy_premium_item_payment_terms do |t|
      t.integer :weight, null: false                                    # the weight assigned to this payment term for calculating total due
      t.references :policy_premium_payment_term,
        index: { name: 'index_ppipt_on_pppt_id' }
      t.references :policy_premium_item,
        index: { name: 'index_ppipt_on_ppi' }
    end
  
    
    create_table :policy_premia do |t|
      # totals
      t.integer :total_premium, null: false, default: 0
      t.integer :total_fee, null: false, default: 0
      t.integer :total_tax, null: false, default: 0
      t.integer :total, null: false, default: 0
      # proration information
      t.boolean :prorated, null: false, default: false
      t.datetime :prorated_term_last_moment
      t.datetime :prorated_term_first_moment
      t.boolean :force_no_refunds, null: false, default: false
      # miscellaneous
      t.timestamps
      t.string  :error_info
      # references
      t.references :policy_quote, null: true
      t.references :policy, null: true
      t.references :commission_strategy
      # garbage
      t.references :archived_policy_premium
    end
    
    
    create_table :line_items do |t|
      # basic details
      t.string      :title, null: false                                 # the title to display on the invoice
      t.boolean     :priced_in, null: false, default: false             # true if this line item has been taken into account in the invoice total (i.e. starts as false and gets set to true once invoice processes the addition)
      t.timestamps
      # payment tracking
      t.integer     :original_total_due,  null: false                   # the total due when this line item was created
      t.integer     :total_due, null: false                             # the total due now (i.e. original_total_due minus refunds plus increases)
      t.integer     :total_reducing, null: false, default: 0            # the amount subtracted from total_due by pending LineItemReductions
      t.integer     :total_received, null: false, default: 0            # the amount received towards payment of total_due
      t.integer     :preproration_total_due, null: false                # the amount due before any prorations MOOSE WARNING: no validations
      t.integer     :duplicatable_reduction_total, null: false, default: 0  # the total of all reductions with proration_interaction 'duplicated' MOOSE WARNING: no validations
      # references
      t.references  :chargeable, polymorphic: true                      # will be a PolicyPremiumItemTerm right now, but could be anything
      t.references  :invoice                                            # the invoice to which this LineItem belongs
      # redundant fields for convenient analytics
      t.integer     :analytics_category, null: false, default: 0
      t.references  :policy_quote, null: true
      # garbage
      t.references :archived_line_item
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
      t.integer     :original_total_due, null: false, default: 0        # the total due when this invoice was created                                       (Automatically given a value in before_create based on LineItems.)
      t.integer     :total_due, null: false, default: 0                 # the total due now (taking refunds & newly added line items into account)          (Automatically given a value in before_create based on LineItems.)
      t.integer     :total_payable, null: false, default: 0             # the total that can be paid now (i.e. total_due - total_pending - total_received)  (Automatically given a value in before_create based on LineItems.)
      t.integer     :total_reducing, null: false, default: 0            # the amount subtracted from total_due by pending LineItemReductions
      t.integer     :total_pending, null: false, default: 0             # the total amount pending (i.e. the sum of charge.amount over all charges with processed: false)
      t.integer     :total_received, null: false, default: 0            # the total that has actually been received
      t.integer     :total_undistributable, null: false, default: 0     # if we receive a payment and the line items totals have somehow changed so that what we charged for has become less than the total, the extra is recorded here
      # associations
      t.references :invoiceable, polymorphic: true
      t.references :payer, polymorphic: true
      t.references :collector, polymorphic: true # MOOSE WARNING: auto-set .external based on this???
      # garbage
      t.references :archived_invoice
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
      t.references :invoice, null: false
      # garbage
      t.references :archived_charge
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
    
    create_table :line_item_changes do |t|
      t.integer     :field_changed, null: false                         # which field was changed (total_due or total_received)
      t.integer     :amount, null: false                                # the change to line_item.total_received (positive or negative)
      t.integer     :new_value, null: false                             # the value of the field after the change
      t.boolean     :handled, null: false, default: false               # whether a handler has handled this LIC (we could just use !lic.handler.nil?, but this is cleaner, and it allows us to retroactively look at folk whose invoice.chargeable_type didn't have any associated logic in the LIC model and who thus just got marked as handled=true)
      t.timestamps
      t.references  :line_item                                          # the LineItem
      t.references  :reason, polymorphic: true                          # the reason for this change (a StripeCharge object, for example, or a LineItemReduction)
      t.references  :handler, polymorphic: true, null: true             # the model that handled us (i.e. transcribed us into commissions... will generally be a PPI)
    end
    
    create_table :line_item_reductions do |t|
      t.string          :reason, null: false                            # String describing the reason for this reduction
      t.integer         :refundability, null: false                     # Enum for whether we can be refunded or only cancelled before payment
      t.integer         :proration_interaction, null: false, default: 0 # How we interact with any future prorations
      t.integer         :amount_interpretation, null: false, default: 0 # Whether "amount" represents amount to reduce by or maximum amount after reduction
      t.integer         :amount, null: false                            # The amount by which the line item total_due should be reduced
      t.integer         :amount_successful, null: false, default: 0     # The amount that actually ended up being reduced (if refunds_allowed, will be total_due_max_reduction; if not, it might be less)
      t.integer         :amount_refunded, null: false, default: 0
      t.boolean         :pending, null: false, default: true            # True iff this LIR hasn't yet been applied
      #t.boolean         :processed, null: false, default: false         # True iff this LIR has completed all its work... MOOSE WARNING: is this needed???
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
    
    create_table :policy_premium_item_commissions do |t|
      t.integer       :status, null: false                              # 'quoted', 'active'
      t.integer       :payability, null: false                          # 'internal', 'external'
      t.integer       :total_expected, null: false                      # the total amount we expect to pay out in commissions for this PPI to this recipient
      t.integer       :total_received,  null: false, defualt: 0         # the total amount we have actually received from the payer
      t.integer       :total_commission, null: false, default: 0        # the total amount we have written CommissionItems for
      t.decimal       :percentage, null: false, precision: 5, scale: 2  # the % of total paid that goes to commissions for recipient (ppi.policy_premium_item_commisions.inject(0){|sum,ppic| sum+ppic} will be equal to 100
      t.integer       :payment_order, null: false                       # a nice integer to sort folk into the proper payment order
      t.timestamps
      t.references    :policy_premium_item                              # the PPI which owns us
      t.references    :recipient, polymorphic: true,                    # the actual recipient of commissions (so not a CommissionStrategy)
        index: { name: 'index_policy_premium_item_commission_on_recipient' }
      t.references    :commission_strategy, null: true                  # if our PPI has recipient_type==CS, we put self.recipient=ppi.recipient.recipient and self.commission_strategy=ppi.recipient; otherwise this will be nil
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
      t.text          :notes                                            # Any explanatory notes about this CI
      t.timestamps
      t.references    :commission                                       # The commission on which this item is listed.
      t.references    :commissionable, polymorphic: true,               # The thing this item is being paid for. Generally will be a PolicyPremiumItemCommission.
        index: { name: 'index_commision_items_on_commissionable' }
      t.references    :reason, polymorphic: true, null: true            # The reason this CI was created (generally a LineItemChange or PolicyPremiumItemTransaction)
      # redundant fields for analytics
      t.references    :policy_quote, null: true
      t.references    :policy, null: true
    end
    
    create_table :policy_premium_item_transaction do |t|
      t.boolean       :pending, null: false, default: true              # Whether this PPIT is pending or has already created CommissionItems
      t.datetime      :create_commission_items_at, null: false          # When to stop pending & create commission items
      t.integer       :amount                                           # The amount of the commission items to create
      t.jsonb         :error_info                                       # If we encounter an error in unleash_commission_item!, we log it here
      t.timestamps
      t.references    :recipient,                                       # The recipient of the commission on which this thing's commision items will be listed.
        index: { name: 'index_ppits_on_recipient' }
      t.references    :commissionable, polymorphic: true,               # The thing this item is being paid for. Generally will be a PolicyPremiumItemCommission.
        index: { name: 'index_ppits_on_commissionable' }
      t.references    :reason, polymorphic: true, null: true,           # The reason this PPIT was created (generally a StripeCharge or LineItemReduction)
        index: { name: 'index_ppits_on_reason' }
      t.references    :policy_premium_item,                             # The PPI we belong to
        index: { name: 'index_ppits_on_ppi' }
      t.index ["pending", "create_commission_items_at"], name: "index_ppits_on_pending_and_ccia"
    end
    
    create_table :policy_premium_item_transaction_membership do |t|
      t.references    :policy_premium_item_transaction,
        index: { name: 'index_ppitms_on_ppit' }
      t.references    :member, polymorphic: true,
        index: { name: 'index_ppitms_on_member' }
    end
  
  end
  
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
