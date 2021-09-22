class UpgradeFinanceSystem < ActiveRecord::Migration[5.2]

  def up
    upgrade_system
    #upgrade_data MOOSE WARNING: no longer here. Instead run lib/utilities/scripts/bigmig/finance-upgrade.rb
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end


  def upgrade_system
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
      t.timestamps
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
      t.references  :policy, null: true
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
      t.references :invoiceable, polymorphic: true, index: { name: 'index_invoices_on_invoiceable_type_and_invoiceable_id' }
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
      t.timestamps
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
      t.integer       :total_received,  null: false, default: 0         # the total amount we have actually received from the payer
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
      t.references    :recipient, polymorphic: true,                    # The recipient of the commission on which this thing's commision items will be listed.
        index: { name: 'index_ppits_on_recipient' }
      t.references    :commissionable, polymorphic: true,               # The thing this item is being paid for. Generally will be a PolicyPremiumItemCommission.
        index: { name: 'index_ppits_on_commissionable' }
      t.references    :reason, polymorphic: true,                       # The reason this PPIT was created (generally a StripeCharge or LineItemReduction)
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
  
  
  
  def upgrade_data
    # Collectors
    ::CarrierAgencyPolicyType.references(:carrier_agencies).includes(:carrier_agency).where(carrier_agencies: { carrier_id: [5] }).update_all(collector_type: 'Carrier', collector_id: 5)
    ::CarrierAgencyPolicyType.references(:carrier_agencies).includes(:carrier_agency).where(carrier_agencies: { carrier_id: [6] }).update_all(collector_type: 'Carrier', collector_id: 6)
    # Policy Premia
    ArchivedPolicyPremium.all.each do |old|
      # grab useful boiz
      p = old.policy
      pq = old.policy_quote
      pa = pq&.policy_application
      pr = pa || p
      cpt = ::CarrierPolicyType.where(carrier_id: pr&.carrier_id, policy_type_id: pr&.policy_type_id).take
      capt = ::CarrierAgencyPolicyType.references(:carrier_agencies).includes(:carrier_agency).where(policy_type_id: pr&.policy_type_id, carrier_agencies: { carrier_id: pr&.carrier_id, agency_id: pr&.agency_id }).take
      cs = capt&.commission_strategy # can't be nil if previous migrations succeeded, so don't bother checking
      if pr.nil?
        puts "Policy premium ##{old.id} is insane; it has no PolicyApplication or Policy!"
        raise Exception
      elsif !pq.nil? && pa.nil?
        puts "Policy premium ##{old.id} has insane policy quote with no PolicyApplication!"
        raise Exception
      elsif cpt.nil?
        puts "Policy premium ##{old.id} has no CarrierPolicyType!"
        raise Exception
      elsif capt.nil?
        puts "Policy premium ##{old.id} has no CarrierAgencyPolicyType! Oh dear, oh my, oh dear!"
        raise Exception
      end
      # handle master policies
      if pr.policy_type_id == ::PolicyType::MASTER_COVERAGE_ID
        puts "Policy premium ##{old.id} belongs to policy of type MASTER POLICY COVERAGE! This is incomprehensible madness!!!"
        raise Exception
      end
      if pr.policy_type_id == ::PolicyType::MASTER_ID
        premium = ::PolicyPremium.create!(
          policy: p,
          commission_strategy: cs,
          total_premium: old.base,
          total_tax: 0,
          total_fee: 0,
          total: old.base,
          prorated: false,
          prorated_term_first_moment: nil,
          prorated_term_last_moment: nil,
          force_no_refunds: false,
          error_info: nil,
          created_at: old.created_at,
          updated_at: old.updated_at,
          archived_policy_premium_id: old.id
        )
        ppi_per_coverage = ::PolicyPremiumItem.create!(
          policy_premium: premium,
          title: "Per-Coverage Premium",
          category: "premium",
          rounding_error_distribution: "first_payment_simple",
          total_due: old.base,
          proration_calculation: "no_proration",
          proration_refunds_allowed: false,
          commission_calculation: "no_payments",
          recipient: premium.commission_strategy,
          collector: ::Agency.where(master_agency: true).take,
          created_at: old.created_at,
          updated_at: old.created_at
        )
        ::ArchivedInvoice.where(invoiceable: p).each do |inv|
          ppi = ::PolicyPremiumItem.create!(
            policy_premium: premium,
            title: "Premium",
            category: "premium",
            rounding_error_distribution: "first_payment_simple",
            total_due: inv.line_items.inject(0){|sum,li| sum + li.price },
            proration_calculation: "no_proration",
            proration_refunds_allowed: false,
            commission_calculation: "group_by_transaction",
            commission_creation_delay_hours: 10,
            recipient: premium.commission_strategy,
            collector: ::Agency.where(master_agency: true).take,
            created_at: old.created_at,
            updated_at: old.created_at
          )
          ppi.policy_premium_item_commissions.update_all(status: 'active')
          pppt = ::PolicyPremiumPaymentTerm.create!(
            policy_premium: premium,
            first_moment: inv.term_first_date.beginning_of_day,
            last_moment: inv.term_last_date.end_of_day,
            time_resolution: 'day',
            invoice_available_date_override: inv.available_date,
            invoice_due_date_override: inv.due_date,
            default_weight: 1,
            created_at: old.created_at,
            updated_at: old.created_at
          )
          ppipt = ::PolicyPremiumItemPaymentTerm.create!(
            policy_premium_item: ppi,
            policy_premium_payment_term: pppt,
            weight: 1,
            created_at: old.created_at,
            updated_at: old.created_at
          )
          invoice = ::Invoice.new(
            number: inv.number,
            available_date: inv.available_date,
            due_date: inv.due_date,
            external: false,
            status: 'quoted',
            status_changed: inv.status_changed,
            was_missed: inv.was_missed,
            was_missed_at: !inv.was_missed ? nil : inv.status == 'missed' ? inv.status_changed : (inv.due_date + 1.day).beginning_of_day,
            autosend_status_change_notifications: true,
            original_total_due: inv.subtotal,
            total_due: inv.total,
            total_payable: inv.total,
            total_reducing: 0, # there are no pending reductions
            total_pending: 0, # there are no pending charges
            total_received: 0, # we'll fix this in just a bit
            total_undistributable: 0,
            invoiceable: p,
            payer: p.account,
            collector: ppi.collector,
            archived_invoice_id: inv.id,
            created_at: inv.created_at,
            updated_at: inv.updated_at
          )
          invoice.callbacks_disabled = true
          invoice.save!
          inv.line_items.map do |li|
            ::LineItem.create!(
              invoice: invoice,
              priced_in: true,
              chargeable: ppipt,
              title: li.title,
              original_total_due: li.price,
              total_due: li.price,
              preproration_total_due: li.price,
              analytics_category: "master_policy_premium",
              policy_quote: nil,
              policy: p,
              archived_line_item_id: li.id,
              created_at: li.created_at,
              updated_at: li.updated_at
            )
          end
          inv.charges.each do |charge|
            # basic setup
            sc = ::StripeCharge.new(
              processed: true,
              invoice_aware: true,
              status: charge.status,
              status_changed_at: charge.updated_at,
              amount: charge.amount,
              amount_refunded: 0,
              source: inv.payer.payment_profiles.where(default: true).take&.source_id,
              customer_stripe_id: inv.payer&.stripe_id,
              description: nil,
              metadata: nil,
              stripe_id: charge.stripe_id,
              error_info: charge.status == 'failed' ? charge.status_information : nil,
              client_error: charge.status == 'failed' ? { linear: ['stripe_charge_model.generic_error'] } : nil,
              created_at: charge.created_at,
              updated_at: charge.updated_at,
              invoice_id: invoice.id,
              archived_charge_id: charge.id
            )
            sc.callbacks_disabled = true
            unless sc.stripe_id.nil?
              from_stripe = (::Stripe::Charge::retrieve(sc.stripe_id) rescue nil)
              unless from_stripe.nil?
                sc.source = from_stripe['source']&.[]('id')
                sc.description = from_stripe['description']
                sc.metadata = from_stripe['metadata'].to_h
              end
            end
            # status-based handling
            case charge.status
              when 'processing', 'pending'
                puts "Charge ##{charge.id} is still '#{charge.status}'; we dare not upgrade until it completes!"
                raise Exception
              when 'failed'
                sc.save!
              when 'succeeded'
                sc.save!
                amount_left = charge.amount
                invoice.line_items.each do |li|
                  dat_amount = [li.total_due, amount_left].min
                  unless dat_amount == 0
                    ::LineItemChange.create!(
                      field_changed: 'total_received',
                      amount: dat_amount,
                      new_value: li.total_received + dat_amount,
                      handled: false,
                      line_item: li,
                      reason: sc,
                      handler: nil,
                      created_at: charge.updated_at,
                      updated_at: charge.updated_at
                    )
                    li.update!(total_received: li.total_received + dat_amount)
                  end
                  amount_left -= dat_amount
                end
            end
          end
          received = invoice.line_items.inject(0){|sum,li| sum + li.total_received }
          invoice.callbacks_disabled = true
          invoice.update!(
            total_payable: invoice.total_due - received,
            total_received: received
          )
          unless inv.status == 'quoted'
            invoice.callbacks_disabled = true
            invoice.update!(status: inv.status == 'canceled' ? 'cancelled' : invoice.get_proper_status)
          end
        end
        # since this is a master policy, we are now done handling it; move on to the next policy premium to upgrade
        next
      end # end handle master policies
      # create PolicyPremium
      total_premium = old.base + (old.include_special_premium ? old.special_premium : 0)
      total_tax = old.taxes
      total_fee = old.total_fees
      prorated = !pq.policy.nil? && pq.policy.status == 'CANCELLED'
      premium = ::PolicyPremium.create!({
        policy_quote_id: pq.id,
        policy_id: old.policy_id,
        commission_strategy: cs,
        total_premium: total_premium,
        total_tax: total_tax,
        total_fee: total_fee,
        total: total_premium + total_tax + total_fee,
        prorated: prorated,
        prorated_term_first_moment: !prorated ? nil : pq.policy.effective_date.to_date.beginning_of_day,
        prorated_term_last_moment: !prorated ? nil : pq.policy.cancellation_date.to_date.end_of_day,
        force_no_refunds: false,
        error_info: nil,
        created_at: old.created_at,
        updated_at: old.updated_at,
        archived_policy_premium_id: old.id
      })
      # create PolicyPremiumPaymentTerms (and grab invoice and line item arrays while we're at it)
      invoices = ::ArchivedInvoice.where(invoiceable: pq).order(term_first_date: :asc).to_a
      if invoices.blank?
        puts "Policy premium ##{old.id} failed the sanity check; it has no invoices!"
        raise Exception
      end
      line_items = ::ArchivedLineItem.where(invoice_id: invoices.map{|i| i.id }).to_a
      pppts = invoices.map do |inv|
        ::PolicyPremiumPaymentTerm.create!(
          policy_premium: premium,
          first_moment: inv.term_first_date.beginning_of_day,
          last_moment: inv.term_last_date.end_of_day,
          time_resolution: 'day',
          default_weight: 1,
          term_group: nil,
          created_at: old.created_at,
          updated_at: old.created_at
        )
      end
      # create new invoices (but no line items yet)
      new_invoices = invoices.map.with_index do |inv, ind|
        to_create = ::Invoice.new(
          number: inv.number,
          description: inv.description,
          available_date: inv.available_date,
          due_date: inv.due_date,
          external: pa.carrier_id == 5 || pa.carrier_id == 6 ? true : false,
          status: inv.status == 'canceled' ? 'cancelled' : pa.carrier_id == 5 || pa.carrier_id == 6 ? 'managed_externally' : 'quoted', # for now! we will update this after handling the line items!
          status_changed: inv.status_changed,
          under_review: false,
          pending_charge_count: 0, # we will scream and die if we encounter a pending charge
          pending_dispute_count: 0,
          error_info: [],
          was_missed: inv.was_missed,
          was_missed_at: !inv.was_missed ? nil : inv.status == 'missed' ? inv.status_changed : (inv.due_date + 1.day).beginning_of_day,
          autosend_status_change_notifications: true,
          # due stuff
          original_total_due: inv.subtotal,
          total_due: inv.total - inv.amount_refunded,
          total_payable: inv.total - inv.amount_refunded,
          total_reducing: 0, # there are no pending reductions
          total_pending: 0, # there are no pending charges
          total_received: 0, # we'll fix this in just a bit
          total_undistributable: 0,
          # assocs
          invoiceable: pq,
          payer: pa.primary_user,
          collector: ::PolicyPremium.default_collector,
          # garbage
          archived_invoice_id: inv.id,
          created_at: inv.created_at,
          updated_at: inv.updated_at
        )
        to_create.callbacks_disabled = true
        to_create.save!
        to_create
      end
      # create PolicyPremiumItems and PolicyPremiumItemPaymentTerms
      case pa.carrier_id
        when 1,2,3,4
          ppi_premium = old.combined_premium == 0 ? nil : ::PolicyPremiumItem.create!(
            policy_premium: premium,
            title: "Premium Installment",
            category: "premium",
            rounding_error_distribution: "first_payment_simple",
            total_due: old.combined_premium,
            proration_calculation: cpt.premium_proration_calculation,
            proration_refunds_allowed: cpt.premium_proration_refunds_allowed,
            recipient: cs,
            collector: ::PolicyPremium.default_collector,
            created_at: old.created_at,
            updated_at: old.created_at
          )
          ppi_premium.policy_premium_item_commissions.update_all(status: 'active') unless pq.policy.nil?
          invoices.map.with_index do |inv, ind|
            lis = line_items.select{|li| li.invoice_id == inv.id && (li.category == 'base_premium' || li.category == 'special_premium') }
            price = lis.inject(0){|sum,li| sum + li.price }
            received = lis.inject(0){|sum,li| sum + li.collected }
            proration_reduction = lis.inject(0){|sum,li| sum + li.proration_reduction }
            next if price == 0
            # premium
            ppipt = ::PolicyPremiumItemPaymentTerm.create!(
              policy_premium_item: ppi_premium,
              policy_premium_payment_term: pppts[ind],
              weight: price,
              created_at: inv.created_at,
              updated_at: inv.created_at
            )
            li = ::LineItem.create!(chargeable: ppipt, invoice: new_invoices[ind], title: "Premium", priced_in: true, analytics_category: "policy_premium", policy_quote: pq,
              original_total_due: price,
              total_due: inv.status == 'canceled' ? received : price - proration_reduction,
              total_reducing: 0,
              total_received: received,
              preproration_total_due: price,
              duplicatable_reduction_total: 0,
              created_at: inv.created_at,
              updated_at: lis.map{|l| l.updated_at }.max,
              archived_line_item_id: lis.first.id
            )
            fake_total_due = price
            fake_total_received = 0
            inv.charges.each do |charge|
              # basic setup
              sc = ::StripeCharge.new(
                processed: true,
                invoice_aware: true,
                status: charge.status,
                status_changed_at: charge.updated_at,
                amount: charge.amount,
                amount_refunded: charge.amount_refunded, # amount_in_queued_refunds is already included in this number
                source: inv.payer.payment_profiles.where(default: true).take&.source_id,
                customer_stripe_id: inv.payer&.stripe_id,
                description: nil,
                metadata: nil,
                stripe_id: charge.stripe_id,
                error_info: charge.status == 'failed' ? charge.status_information : nil,
                client_error: charge.status == 'failed' ? { linear: ['stripe_charge_model.generic_error'] } : nil,
                created_at: charge.created_at,
                updated_at: charge.updated_at,
                invoice_id: new_invoices[ind].id,
                archived_charge_id: charge.id
              )
              sc.callbacks_disabled = true
              unless sc.stripe_id.nil?
                from_stripe = (::Stripe::Charge::retrieve(sc.stripe_id) rescue nil)
                unless from_stripe.nil?
                  sc.source = from_stripe['source']&.[]('id')
                  sc.description = from_stripe['description']
                  sc.metadata = from_stripe['metadata'].to_h
                end
              end
              # status-based handling
              case charge.status
                when 'processing', 'pending'
                  puts "Charge ##{charge.id} is still '#{charge.status}'; we dare not upgrade until it completes!"
                  raise Exception
                when 'failed'
                  sc.save!
                when 'succeeded'
                  sc.save!
                  ::LineItemChange.create!(
                    field_changed: 'total_received',
                    amount: charge.amount,
                    new_value: (fake_total_received += charge.amount),
                    handled: false,
                    line_item: li,
                    reason: sc,
                    handler: nil,
                    created_at: charge.updated_at,
                    updated_at: charge.updated_at
                  )
                  charge.refunds.each do |refund|
                    refund.full_reason ||= "Refund" # just in case it was nil, since that won't fly no more
                    new_refund = ::Refund.create!(
                      refund_reasons: [refund.full_reason],
                      amount: refund.amount,
                      amount_refunded: refund.amount,
                      amount_returned_by_dispute: 0,
                      complete: true,
                      invoice: new_invoices[ind],
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                    stripe_refund = ::StripeRefund.create!(
                      status: case refund.status
                        when 'processing';                    'awaiting_execution'
                        when 'queued';                        'awaiting_execution'
                        when 'pending';                       'pending'
                        when 'succeeded';                     'succeeded'
                        when 'succeeded_via_dispute_payout';  'succeeded'
                        when 'failed';                        'failed'
                        when 'errored';                       'errored'
                        when 'failed_and_handled';            refund.stripe_status == 'succeeded' ? 'succeeded' : 'succeeded_manually'
                      end,
                      full_reasons: [refund.full_reason],
                      amount: refund.amount,
                      stripe_id: refund.stripe_id,
                      stripe_reason: refund.stripe_reason,
                      stripe_status: refund.stripe_status,
                      failure_reason: refund.failure_reason,
                      receipt_number: refund.receipt_number,
                      error_message: refund.error_message,
                      refund: new_refund,
                      stripe_charge: sc,
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                    lir = ::LineItemReduction.new(
                      reason: refund.full_reason,
                      refundability: 'cancel_or_refund',
                      proration_interaction: 'shared',
                      amount_interpretation: 'max_amount_to_reduce',
                      amount: refund.amount,
                      amount_successful: refund.amount,
                      amount_refunded: refund.amount,
                      pending: false,
                      line_item: li,
                      dispute: nil,
                      refund: new_refund,
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                    lir.callbacks_disabled = true
                    lir.save!
                    ::LineItemChange.create!(
                      field_changed: 'total_due',
                      amount: -refund.amount,
                      new_value: (fake_total_due -= refund.amount),
                      handled: false,
                      line_item: li,
                      reason: lir,
                      handler: nil,
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                    ::LineItemChange.create!(
                      field_changed: 'total_received',
                      amount: -refund.amount,
                      new_value: (fake_total_received -= refund.amount),
                      handled: false,
                      line_item: li,
                      reason: lir,
                      handler: nil,
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                  end

              end
            end
            # fix up invoice status and totals
            ninv = new_invoices[ind]
            received = ninv.line_items.inject(0){|sum,li| sum + li.total_received }
            ninv.callbacks_disabled = true
            ninv.update!(
              total_payable: ninv.total_payable - received,
              total_received: received
            )
            unless inv.status == 'quoted'
              ninv.callbacks_disabled = true
              ninv.update!(status: inv.status == 'canceled' ? 'cancelled' : ninv.get_proper_status)
            end
          end
        when 5
          # build the PPIs
          msi_policy_fee = pq.carrier_payment_data["policy_fee"]
          installment_total = old.external_fees
          down_payment = ::ArchivedInvoice.where(invoiceable: pq).order('created_at asc').first.line_items.find{|li| li.category == 'base_premium' }.price - pq.carrier_payment_data["policy_fee"]
          installment_per = old.base - down_payment - msi_policy_fee
          ppi_policy_fee = msi_policy_fee == 0 ? nil : ::PolicyPremiumItem.create!(
            policy_premium: premium,
            title: "Policy Fee",
            category: "fee",
            rounding_error_distribution: "first_payment_simple",
            total_due: msi_policy_fee,
            proration_calculation: "no_proration",
            proration_refunds_allowed: false,
            recipient: ::MsiService.carrier,
            collector: ::MsiService.carrier
          )
          ppi_installment_fee = installment_total == 0 ? nil : ::PolicyPremiumItem.create!(
            policy_premium: premium,
            title: "Installment Fee",
            category: "fee",
            rounding_error_distribution: "first_payment_simple",
            total_due: installment_total,
            proration_calculation: "no_proration",
            proration_refunds_allowed: false,
            recipient: ::MsiService.carrier,
            collector: ::MsiService.carrier
          )
          ppi_down_payment = down_payment == 0 ? nil : ::PolicyPremiumItem.create!(
            policy_premium: premium,
            title: "Premium Down Payment",
            category: "premium",
            rounding_error_distribution: "first_payment_simple",
            total_due: down_payment,
            proration_calculation: "no_proration",
            proration_refunds_allowed: false,
            recipient: premium.commission_strategy,
            collector: ::MsiService.carrier
          )
          ppi_installment = installment_per == 0 ? nil : ::PolicyPremiumItem.create!(
            policy_premium: premium,
            title: "Premium Installment",
            category: "premium",
            rounding_error_distribution: "first_payment_simple",
            total_due: installment_per,
            proration_calculation: "no_proration",
            proration_refunds_allowed: false,
            recipient: premium.commission_strategy,
            collector: ::MsiService.carrier
          )
          premium.update_totals(persist: true)
          ppis = { policy_fee: ppi_policy_fee, installment_fee: ppi_installment_fee, down_payment: ppi_down_payment, installment: ppi_installment }.compact
          ppis.values.each{|ppiboi| ppiboi.policy_premium_item_commissions.update_all(status: 'active') } unless pq.policy.nil?
          # generate terms
          ppi_pts = ppis.map do |ppi_name, ppi|
            [
              ppi_name,
              pppts.map.with_index do |pppt, index|
                next if (ppi_name == :policy_fee || ppi_name == :down_payment) && index > 0
                next if (ppi_name == :installment_fee || ppi_name == :installment) && index == 0
                ::PolicyPremiumItemPaymentTerm.create!(
                  policy_premium_item: ppi,
                  policy_premium_payment_term: pppt,
                  weight: ppi_name == :policy_fee ? msi_policy_fee
                    : new_invoices[index].line_items.select{|li| li.category == (ppi_name == :installment_fee ? 'amortized_fees' : 'base_premium') }.inject(0){|s,l| s + l.price },
                  created_at: pppt.created_at,
                  updated_at: pppt.created_at
                )
              end
            ]
          end.to_h
          # generate line items
          ppi_pts.each do |ppi_name, ppi_pts|
            ppi_pts.each.with_index do |ppi_pt, index|
              next if ppi_pt.nil?
              ::LineItem.create!(chargeable: ppi_pt, invoice: new_invoices[index], title: ppis[ppi_name].title, priced_in: true,
                analytics_category: ppi_name == :policy_fee || ppi_name == :installment_fee ? "policy_fee" : "policy_premium",
                policy_quote: pq,
                original_total_due: ppi_pt.weight,
                total_due: ppi_pt.weight,
                total_reducing: 0,
                total_received: 0,
                preproration_total_due: ppi_pt.weight,
                duplicatable_reduction_total: 0,
                created_at: new_invoices[index].created_at,
                updated_at: new_invoices[index].updated_at,
                archived_line_item_id: nil # since we are breaking out the policy fee (which was counted as part of the premium before)
              )
            end
          end
          # update invoices... (just status)
          new_invoices.each do |ninv|
            if ::ArchivedInvoice.where(id: ninv.archived_invoice_id).take.status == 'canceled'
              ninv.callbacks_disabled = true
              ninv.update!(status: 'cancelled')
            end
          end
        when 6
          puts "Policy Premium ##{old.id} belongs to Deposit Choice policy! Oh noooooo!!!"
          raise Exception
        else
          # MOOSE WARNING: some nils exist, don't they??? is that from missing policy_applications >____>???
      end
      
    end
    
  end
  
end









=begin

# Standalone sanity_check method to call on PolicyPremiums in the DB for convenience before the migration

def sanity_check(old)
  # fee calculations
  deposit_fees = old.fees.where(amortize: false, per_payment: false, enabled: true).to_a
  amortized_fees = old.fees.where(amortize: true).or(old.fees.where(per_payment: true)).where(enabled: true).to_a
  line_items = ::LineItem.where(invoice_id: (old.policy_quote&.invoices || []).map{|i| i.id }).to_a
  # sanity check
  deposit_fees_total = deposit_fees.inject(0){|sum,fee| sum + (fee.FLAT? ? fee.amount : (fee.amount / 100.to_d * old.combined_premium).floor ) }
  amortized_fees_total = amortized_fees.inject(0){|sum,fee| sum + ((fee.FLAT? ? fee.amount : fee.amount / 100.to_d * old.combined_premium)*(fee.per_payment ? old.policy_quote.invoices.count : 1)).floor }
  tr = {}
  tr[:deposit] = "wrong" if deposit_fees_total != old.deposit_fees
  tr[:amortized] = "wrong" if amortized_fees_total != old.amortized_fees
  if line_items.blank?
    tr[:line_items] = "missing"
  else
    tr[:li_deposit] = "wrong" if line_items.select{|li| li.category == 'deposit_fees' }.inject(0){|sum,li| sum+li.price } != deposit_fees_total && ![5,6].contain?(old.policy_quote&.policy_application&.carrier_id)
    tr[:li_amortized] = "wrong" if line_items.select{|li| li.category == 'amortized_fees' }.inject(0){|sum,li| sum+li.price } != amortized_fees_total && ![5,6].contain?(old.policy_quote&.policy_application&.carrier_id)
  end
  tr = nil if tr.blank?
  tr[:id] = old.id unless tr.nil?
  return tr
end




=end
