# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_07_02_010801) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.string "call_sign"
    t.boolean "enabled", default: false, null: false
    t.boolean "whitelabel", default: false, null: false
    t.boolean "tos_accepted", default: false, null: false
    t.datetime "tos_accepted_at"
    t.string "tos_acceptance_ip"
    t.boolean "verified", default: false, null: false
    t.string "stripe_id"
    t.jsonb "contact_info", default: {}
    t.jsonb "settings", default: {}
    t.bigint "staff_id"
    t.bigint "agency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_accounts_on_agency_id"
    t.index ["call_sign"], name: "index_accounts_on_call_sign", unique: true
    t.index ["staff_id"], name: "index_accounts_on_staff_id"
    t.index ["stripe_id"], name: "index_accounts_on_stripe_id", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "street_number"
    t.string "street_name"
    t.string "street_two"
    t.string "city"
    t.integer "state"
    t.string "county"
    t.string "zip_code"
    t.string "plus_four"
    t.string "country"
    t.string "full"
    t.string "full_searchable"
    t.float "latitude"
    t.float "longitude"
    t.string "timezone"
    t.string "addressable_type"
    t.bigint "addressable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable_type_and_addressable_id"
  end

  create_table "agencies", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.string "call_sign"
    t.boolean "enabled", default: false, null: false
    t.boolean "whitelabel", default: false, null: false
    t.boolean "tos_accepted", default: false, null: false
    t.datetime "tos_accepted_at"
    t.string "tos_acceptance_ip"
    t.boolean "verified", default: false, null: false
    t.string "stripe_id"
    t.boolean "master_agency", default: false, null: false
    t.jsonb "contact_info", default: {}
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "staff_id"
    t.index ["call_sign"], name: "index_agencies_on_call_sign", unique: true
    t.index ["staff_id"], name: "index_agencies_on_staff_id"
    t.index ["stripe_id"], name: "index_agencies_on_stripe_id", unique: true
  end

  create_table "application_modules", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.jsonb "nodes", default: {}
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "assignments", force: :cascade do |t|
    t.bigint "stuff_id"
    t.string "assignable_type"
    t.bigint "assignable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignable_type", "assignable_id"], name: "index_assignments_on_assignable_type_and_assignable_id"
    t.index ["stuff_id"], name: "index_assignments_on_stuff_id"
  end

  create_table "billing_strategies", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.boolean "enabled", default: false, null: false
    t.jsonb "new_business", default: {"payments"=>[100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "payments_per_term"=>1, "remainder_added_to_deposit"=>true}
    t.jsonb "renewal"
    t.boolean "locked", default: false, null: false
    t.bigint "agency_id"
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_billing_strategies_on_agency_id"
    t.index ["carrier_id"], name: "index_billing_strategies_on_carrier_id"
    t.index ["policy_type_id"], name: "index_billing_strategies_on_policy_type_id"
  end

  create_table "branding_profiles", force: :cascade do |t|
    t.string "title"
    t.string "url"
    t.boolean "default", default: false, null: false
    t.jsonb "styles"
    t.string "profileable_type"
    t.bigint "profileable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profileable_type", "profileable_id"], name: "index_branding_profiles_on_profileable_type_and_profileable_id"
    t.index ["url"], name: "index_branding_profiles_on_url", unique: true
  end

  create_table "carrier_agencies", force: :cascade do |t|
    t.string "external_carrier_id"
    t.bigint "carrier_id"
    t.bigint "agency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_carrier_agencies_on_agency_id"
    t.index ["carrier_id"], name: "index_carrier_agencies_on_carrier_id"
    t.index ["external_carrier_id"], name: "index_carrier_agencies_on_external_carrier_id", unique: true
  end

  create_table "carrier_agency_authorizations", force: :cascade do |t|
    t.integer "state"
    t.boolean "available", default: false, null: false
    t.jsonb "zip_code_blacklist", default: []
    t.bigint "carrier_agency_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_agency_id"], name: "index_carrier_agency_authorizations_on_carrier_agency_id"
    t.index ["policy_type_id"], name: "index_carrier_agency_authorizations_on_policy_type_id"
  end

  create_table "carrier_policy_type_availabilities", force: :cascade do |t|
    t.integer "state"
    t.boolean "available", default: false, null: false
    t.jsonb "zip_code_blacklist", default: []
    t.bigint "carrier_policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_policy_type_id"], name: "index_carrier_policy_availability"
  end

  create_table "carrier_policy_types", force: :cascade do |t|
    t.jsonb "defaults", default: {"options"=>{}, "deductibles"=>{}, "coverage_limits"=>{}}
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id"], name: "index_carrier_policy_types_on_carrier_id"
    t.index ["policy_type_id"], name: "index_carrier_policy_types_on_policy_type_id"
  end

  create_table "carriers", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.string "call_sign"
    t.string "integration_designation"
    t.boolean "syncable", default: false, null: false
    t.boolean "rateable", default: false, null: false
    t.boolean "quotable", default: false, null: false
    t.boolean "bindable", default: false, null: false
    t.boolean "verifiable", default: false, null: false
    t.boolean "enabled", default: false, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "charges", force: :cascade do |t|
    t.integer "status", default: 0
    t.string "status_information"
    t.integer "refund_status", default: 0
    t.integer "payment_method", default: 0
    t.integer "amount_returned_via_dispute", default: 0
    t.integer "amount_refunded", default: 0
    t.integer "amount_lost_to_disputes", default: 0
    t.integer "amount_in_queued_refunds", default: 0
    t.integer "dispute_count", default: 0
    t.string "stripe_id"
    t.bigint "invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_charges_on_invoice_id"
    t.index ["stripe_id"], name: "charge_stripe_id"
  end

  create_table "claims", force: :cascade do |t|
    t.string "subject"
    t.text "description"
    t.datetime "time_of_loss"
    t.integer "status", default: 0
    t.string "claimant_type"
    t.bigint "claimant_id"
    t.bigint "insurable_id"
    t.bigint "policy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claimant_type", "claimant_id"], name: "index_claims_on_claimant_type_and_claimant_id"
    t.index ["insurable_id"], name: "index_claims_on_insurable_id"
    t.index ["policy_id"], name: "index_claims_on_policy_id"
  end

  create_table "commission_strategies", force: :cascade do |t|
    t.integer "amount", default: 10, null: false
    t.integer "type", default: 0, null: false
    t.integer "fulfillment_schedule", default: 0, null: false
    t.boolean "amortize", default: false, null: false
    t.boolean "per_payment", default: false, null: false
    t.boolean "enabled", default: false, null: false
    t.boolean "locked", default: false, null: false
    t.integer "house_override", default: 10, null: false
    t.integer "override_type", default: 0, null: false
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.string "commissionable_type"
    t.bigint "commissionable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "commission_strategy_id"
    t.index ["carrier_id"], name: "index_commission_strategies_on_carrier_id"
    t.index ["commission_strategy_id"], name: "index_commission_strategies_on_commission_strategy_id"
    t.index ["commissionable_type", "commissionable_id"], name: "index_strategy_on_type_and_id"
    t.index ["policy_type_id"], name: "index_commission_strategies_on_policy_type_id"
  end

  create_table "commissions", force: :cascade do |t|
    t.integer "amount"
    t.integer "deductions"
    t.integer "total"
    t.boolean "approved"
    t.date "distributes"
    t.boolean "paid"
    t.string "stripe_transaction_id"
    t.bigint "policy_premium_id"
    t.bigint "commission_strategy_id"
    t.string "commissionable_type"
    t.bigint "commissionable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commission_strategy_id"], name: "index_commissions_on_commission_strategy_id"
    t.index ["commissionable_type", "commissionable_id"], name: "index_commissions_on_commissionable_type_and_commissionable_id"
    t.index ["policy_premium_id"], name: "index_commissions_on_policy_premium_id"
  end

  create_table "disputes", force: :cascade do |t|
    t.string "stripe_id"
    t.integer "amount"
    t.integer "reason"
    t.integer "status"
    t.boolean "active"
    t.bigint "charge_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_id"], name: "index_disputes_on_charge_id"
    t.index ["status"], name: "dispute_status"
    t.index ["stripe_id"], name: "dispute_stripe_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "verb", default: 0
    t.integer "format", default: 0
    t.integer "interface", default: 0
    t.string "process"
    t.string "endpoint"
    t.datetime "started"
    t.datetime "completed"
    t.text "request"
    t.text "response"
    t.string "eventable_type"
    t.bigint "eventable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable_type_and_eventable_id"
  end

  create_table "fees", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.integer "amount", default: 0, null: false
    t.integer "amount_type", default: 0, null: false
    t.integer "type", default: 0, null: false
    t.boolean "per_payment", default: false, null: false
    t.boolean "amortize", default: false, null: false
    t.boolean "enabled", default: false, null: false
    t.boolean "locked", default: false, null: false
    t.string "assignable_type"
    t.bigint "assignable_id"
    t.string "ownerable_type"
    t.bigint "ownerable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignable_type", "assignable_id"], name: "index_fees_on_assignable_type_and_assignable_id"
    t.index ["ownerable_type", "ownerable_id"], name: "index_fees_on_ownerable_type_and_ownerable_id"
  end

  create_table "histories", force: :cascade do |t|
    t.integer "action", default: 0
    t.json "data", default: {}
    t.string "recordable_type"
    t.bigint "recordable_id"
    t.string "authorable_type"
    t.bigint "authorable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["authorable_type", "authorable_id"], name: "index_histories_on_authorable_type_and_authorable_id"
    t.index ["recordable_type", "recordable_id"], name: "index_histories_on_recordable_type_and_recordable_id"
  end

  create_table "insurable_rates", force: :cascade do |t|
    t.string "title"
    t.string "schedule"
    t.string "sub_schedule"
    t.text "description"
    t.boolean "liability_only"
    t.integer "number_insured"
    t.jsonb "deductibles", default: {}
    t.jsonb "coverage_limits", default: {}
    t.integer "interval", default: 0
    t.integer "premium", default: 0
    t.boolean "activated"
    t.date "activated_on"
    t.date "deactivated_on"
    t.boolean "paid_in_full"
    t.bigint "carrier_id"
    t.bigint "agency_id"
    t.bigint "insurable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_insurable_rates_on_agency_id"
    t.index ["carrier_id"], name: "index_insurable_rates_on_carrier_id"
    t.index ["insurable_id"], name: "index_insurable_rates_on_insurable_id"
  end

  create_table "insurable_types", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.integer "category"
    t.jsonb "profile_attributes", default: {}
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "insurables", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.boolean "enabled", default: false
    t.bigint "account_id"
    t.bigint "insurable_type_id"
    t.bigint "insurable_id"
    t.integer "category", default: 0
    t.jsonb "profile", default: {}
    t.boolean "covered", default: false
    t.jsonb "carrier_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_insurables_on_account_id"
    t.index ["insurable_id"], name: "index_insurables_on_insurable_id"
    t.index ["insurable_type_id"], name: "index_insurables_on_insurable_type_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.string "number"
    t.integer "status", default: 0
    t.datetime "status_changed"
    t.text "description"
    t.date "due_date"
    t.date "available_date"
    t.date "term_first_date"
    t.date "term_last_date"
    t.integer "renewal_cycle", default: 0
    t.integer "total", default: 0
    t.integer "subtotal", default: 0
    t.integer "tax", default: 0
    t.decimal "tax_percent", precision: 5, scale: 2, default: "0.0"
    t.jsonb "system_data", default: {}
    t.integer "amount_refunded", default: 0
    t.integer "amount_to_refund_on_completion", default: 0
    t.boolean "has_pending_refund", default: false
    t.jsonb "pending_refund_data", default: {}
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "lease_type_insurable_types", force: :cascade do |t|
    t.boolean "enabled", default: true
    t.bigint "lease_type_id"
    t.bigint "insurable_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["insurable_type_id"], name: "index_lease_type_insurable_types_on_insurable_type_id"
    t.index ["lease_type_id"], name: "index_lease_type_insurable_types_on_lease_type_id"
  end

  create_table "lease_type_policy_types", force: :cascade do |t|
    t.boolean "enabled", default: true
    t.bigint "lease_type_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lease_type_id"], name: "index_lease_type_policy_types_on_lease_type_id"
    t.index ["policy_type_id"], name: "index_lease_type_policy_types_on_policy_type_id"
  end

  create_table "lease_types", force: :cascade do |t|
    t.string "title"
    t.boolean "enabled", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lease_users", force: :cascade do |t|
    t.bigint "lease_id"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lease_id"], name: "index_lease_users_on_lease_id"
    t.index ["user_id"], name: "index_lease_users_on_user_id"
  end

  create_table "leases", force: :cascade do |t|
    t.string "reference"
    t.date "start_date"
    t.date "end_date"
    t.string "type"
    t.integer "status", default: 0
    t.boolean "covered", default: false
    t.bigint "unit_id"
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_leases_on_account_id"
    t.index ["reference"], name: "lease_reference", unique: true
    t.index ["unit_id"], name: "index_leases_on_unit_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.string "title"
    t.integer "price", default: 0
    t.bigint "invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_line_items_on_invoice_id"
  end

  create_table "modifiers", force: :cascade do |t|
    t.integer "strategy"
    t.float "amount"
    t.integer "tier", default: 0
    t.integer "condition", default: 0
    t.bigint "invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_modifiers_on_invoice_id"
  end

  create_table "module_permissions", force: :cascade do |t|
    t.bigint "application_module_id"
    t.string "permissable_type"
    t.bigint "permissable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_module_id"], name: "index_module_permissions_on_application_module_id"
    t.index ["permissable_type", "permissable_id"], name: "permissable_access_index"
  end

  create_table "notes", force: :cascade do |t|
    t.text "content"
    t.string "excerpt"
    t.integer "visibility", default: 0, null: false
    t.bigint "staff_id"
    t.string "noteable_type"
    t.bigint "noteable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["noteable_type", "noteable_id"], name: "index_notes_on_noteable_type_and_noteable_id"
    t.index ["staff_id"], name: "index_notes_on_staff_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "subject"
    t.text "message"
    t.integer "status", default: 0
    t.integer "delivery_method", default: 0
    t.integer "code", default: 0
    t.integer "action", default: 0
    t.integer "template", default: 0
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
  end

  create_table "payments", force: :cascade do |t|
    t.boolean "active"
    t.integer "status"
    t.integer "amount"
    t.integer "reason"
    t.string "stripe_id"
    t.bigint "charge_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_id"], name: "index_payments_on_charge_id"
    t.index ["stripe_id"], name: "stripe_payment", unique: true
  end

  create_table "policies", force: :cascade do |t|
    t.string "number"
    t.date "effective_date"
    t.date "expiration_date"
    t.boolean "auto_renew", default: false, null: false
    t.date "last_renewed_on"
    t.integer "renew_count"
    t.integer "billing_status"
    t.integer "billing_dispute_count"
    t.date "billing_behind_since"
    t.integer "cancellation_code"
    t.string "cancellation_date_date"
    t.integer "status"
    t.datetime "status_changed_on"
    t.integer "billing_dispute_status"
    t.boolean "billing_enabled", default: false, null: false
    t.boolean "system_purchased", default: false, null: false
    t.boolean "serviceable", default: false, null: false
    t.boolean "has_outstanding_refund", default: false, null: false
    t.jsonb "system_data", default: {}
    t.bigint "insurable_id"
    t.bigint "agency_id"
    t.bigint "account_id"
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_policies_on_account_id"
    t.index ["agency_id"], name: "index_policies_on_agency_id"
    t.index ["carrier_id"], name: "index_policies_on_carrier_id"
    t.index ["insurable_id"], name: "index_policies_on_insurable_id"
    t.index ["policy_type_id"], name: "index_policies_on_policy_type_id"
  end

  create_table "policy_applications", force: :cascade do |t|
    t.string "reference"
    t.string "external_reference"
    t.date "effective_date"
    t.date "expiration_date"
    t.integer "status", default: 0, null: false
    t.datetime "status_updated_on"
    t.jsonb "fields", default: {}
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.bigint "agency_id"
    t.bigint "account_id"
    t.bigint "policy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_policy_applications_on_account_id"
    t.index ["agency_id"], name: "index_policy_applications_on_agency_id"
    t.index ["carrier_id"], name: "index_policy_applications_on_carrier_id"
    t.index ["policy_id"], name: "index_policy_applications_on_policy_id"
    t.index ["policy_type_id"], name: "index_policy_applications_on_policy_type_id"
  end

  create_table "policy_coverages", force: :cascade do |t|
    t.string "coverage_type"
    t.string "display_title"
    t.integer "limit", default: 0
    t.integer "deductible", default: 0
    t.boolean "enabled", default: false, null: false
    t.datetime "enabled_changed"
    t.bigint "policy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_id"], name: "index_policy_coverages_on_policy_id"
  end

  create_table "policy_premia", force: :cascade do |t|
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
    t.index ["billing_strategy_id"], name: "index_policy_premia_on_billing_strategy_id"
    t.index ["commission_strategy_id"], name: "index_policy_premia_on_commission_strategy_id"
    t.index ["policy_id"], name: "index_policy_premia_on_policy_id"
    t.index ["policy_quote_id"], name: "index_policy_premia_on_policy_quote_id"
  end

  create_table "policy_premium_fees", force: :cascade do |t|
    t.bigint "policy_premium_id"
    t.bigint "fee_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fee_id"], name: "index_policy_premium_fees_on_fee_id"
    t.index ["policy_premium_id"], name: "index_policy_premium_fees_on_policy_premium_id"
  end

  create_table "policy_quotes", force: :cascade do |t|
    t.string "reference"
    t.string "external_reference"
    t.integer "status"
    t.datetime "status_updated_on"
    t.integer "premium"
    t.integer "tax"
    t.integer "est_fees"
    t.integer "total_premium"
    t.bigint "policy_application_id"
    t.bigint "agency_id"
    t.bigint "account_id"
    t.bigint "policy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_policy_quotes_on_account_id"
    t.index ["agency_id"], name: "index_policy_quotes_on_agency_id"
    t.index ["policy_application_id"], name: "index_policy_quotes_on_policy_application_id"
    t.index ["policy_id"], name: "index_policy_quotes_on_policy_id"
  end

  create_table "policy_types", force: :cascade do |t|
    t.string "title"
    t.integer "slug"
    t.jsonb "defaults", default: {"options"=>{}, "deductibles"=>{}, "coverage_limits"=>{}}
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "policy_users", force: :cascade do |t|
    t.boolean "primary", default: false, null: false
    t.boolean "spouse", default: false, null: false
    t.bigint "policy_application_id"
    t.bigint "policy_id"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_application_id"], name: "index_policy_users_on_policy_application_id"
    t.index ["policy_id"], name: "index_policy_users_on_policy_id"
    t.index ["user_id"], name: "index_policy_users_on_user_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.string "title"
    t.string "suffix"
    t.string "full_name"
    t.string "contact_email"
    t.string "contact_phone"
    t.date "birth_date"
    t.string "profileable_type"
    t.bigint "profileable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profileable_type", "profileable_id"], name: "index_profiles_on_profileable_type_and_profileable_id"
  end

  create_table "refunds", force: :cascade do |t|
    t.string "stripe_id"
    t.integer "amount"
    t.string "currency"
    t.string "failure_reason"
    t.integer "stripe_reason"
    t.string "receipt_number"
    t.integer "stripe_status"
    t.integer "status"
    t.string "full_reason"
    t.string "error_message"
    t.integer "amount_returned_via_dispute", default: 0
    t.bigint "charge_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_id"], name: "index_refunds_on_charge_id"
    t.index ["status"], name: "refund_status"
    t.index ["stripe_id"], name: "refund_stripe_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "allow_password_change", default: false
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "email"
    t.boolean "enabled", default: false, null: false
    t.jsonb "settings", default: {}
    t.jsonb "notification_options", default: {}
    t.boolean "owner", default: false, null: false
    t.string "organizable_type"
    t.bigint "organizable_id"
    t.json "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "role", default: 0
    t.index ["confirmation_token"], name: "index_staffs_on_confirmation_token", unique: true
    t.index ["email"], name: "index_staffs_on_email", unique: true
    t.index ["invitation_token"], name: "index_staffs_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_staffs_on_invitations_count"
    t.index ["invited_by_id"], name: "index_staffs_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_staffs_on_invited_by_type_and_invited_by_id"
    t.index ["organizable_type", "organizable_id"], name: "index_staffs_on_organizable_type_and_organizable_id"
    t.index ["reset_password_token"], name: "index_staffs_on_reset_password_token", unique: true
    t.index ["role"], name: "index_staffs_on_role"
    t.index ["uid", "provider"], name: "index_staffs_on_uid_and_provider", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "allow_password_change", default: false
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "email"
    t.boolean "enabled", default: false, null: false
    t.jsonb "settings", default: {}
    t.jsonb "notification_options", default: {}
    t.boolean "owner", default: false, null: false
    t.boolean "user_in_system"
    t.json "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by_type_and_invited_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
  end

end
