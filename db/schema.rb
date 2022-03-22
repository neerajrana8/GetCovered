# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_03_22_160538) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "access_tokens", force: :cascade do |t|
    t.string "key"
    t.string "secret"
    t.string "secret_hash"
    t.string "secret_salt"
    t.boolean "enabled"
    t.string "bearer_type"
    t.bigint "bearer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "access_type", default: 0, null: false
    t.jsonb "access_data"
    t.datetime "expires_at"
    t.index ["bearer_type", "bearer_id"], name: "index_access_tokens_on_bearer"
    t.index ["expires_at"], name: "access_tokens_expires_at_index"
    t.index ["key"], name: "access_tokens_key_index"
  end

  create_table "account_users", force: :cascade do |t|
    t.integer "status", default: 0
    t.bigint "account_id"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_users_on_account_id"
    t.index ["user_id"], name: "index_account_users_on_user_id"
  end

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
    t.string "payment_profile_stripe_id"
    t.integer "current_payment_method"
    t.boolean "additional_interest", default: true
    t.index ["agency_id"], name: "index_accounts_on_agency_id"
    t.index ["call_sign"], name: "index_accounts_on_call_sign", unique: true
    t.index ["staff_id"], name: "index_accounts_on_staff_id"
    t.index ["stripe_id"], name: "index_accounts_on_stripe_id", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
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
    t.boolean "primary", default: false, null: false
    t.string "addressable_type"
    t.bigint "addressable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "searchable", default: false
    t.string "neighborhood"
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable"
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
    t.bigint "agency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "staff_id"
    t.string "integration_designation"
    t.string "producer_code"
    t.jsonb "carrier_preferences", default: {"by_policy_type"=>{}}, null: false
    t.index ["agency_id"], name: "index_agencies_on_agency_id"
    t.index ["call_sign"], name: "index_agencies_on_call_sign", unique: true
    t.index ["integration_designation"], name: "index_agencies_on_integration_designation", unique: true
    t.index ["producer_code"], name: "index_agencies_on_producer_code", unique: true
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

  create_table "archived_charges", force: :cascade do |t|
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
    t.integer "amount", default: 0
    t.boolean "invoice_update_failed", default: false, null: false
    t.string "invoice_update_error_call"
    t.string "invoice_update_error_record"
    t.jsonb "invoice_update_error_hash"
    t.index ["invoice_id"], name: "index_archived_charges_on_invoice_id"
    t.index ["stripe_id"], name: "charge_stripe_id"
  end

  create_table "archived_commission_deductions", force: :cascade do |t|
    t.integer "unearned_balance"
    t.string "deductee_type"
    t.bigint "deductee_id"
    t.bigint "policy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deductee_type", "deductee_id"], name: "index_craptastic_garbage_why_is_there_a_length_limit_ugh"
    t.index ["policy_id"], name: "index_archived_commission_deductions_on_policy_id"
  end

  create_table "archived_commission_strategies", force: :cascade do |t|
    t.string "title", null: false
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
    t.decimal "percentage", precision: 5, scale: 2, default: "0.0"
    t.index ["carrier_id"], name: "index_archived_commission_strategies_on_carrier_id"
    t.index ["commission_strategy_id"], name: "index_archived_commission_strategies_on_commission_strategy_id"
    t.index ["commissionable_type", "commissionable_id"], name: "index_strategy_on_type_and_id"
    t.index ["policy_type_id"], name: "index_archived_commission_strategies_on_policy_type_id"
  end

  create_table "archived_commissions", force: :cascade do |t|
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
    t.index ["commission_strategy_id"], name: "index_archived_commissions_on_commission_strategy_id"
    t.index ["commissionable_type", "commissionable_id"], name: "index_archived_commissions_on_commissionable"
    t.index ["policy_premium_id"], name: "index_archived_commissions_on_policy_premium_id"
  end

  create_table "archived_disputes", force: :cascade do |t|
    t.string "stripe_id"
    t.integer "amount"
    t.integer "reason"
    t.integer "status"
    t.boolean "active", default: true, null: false
    t.bigint "charge_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_id"], name: "index_archived_disputes_on_charge_id"
    t.index ["status"], name: "dispute_status"
    t.index ["stripe_id"], name: "dispute_stripe_id"
  end

  create_table "archived_invoices", force: :cascade do |t|
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invoiceable_type"
    t.bigint "invoiceable_id"
    t.integer "proration_reduction", default: 0, null: false
    t.integer "disputed_charge_count", default: 0, null: false
    t.boolean "was_missed", default: false, null: false
    t.string "payer_type"
    t.bigint "payer_id"
    t.boolean "external", default: false, null: false
    t.index ["invoiceable_type", "invoiceable_id"], name: "index_invoices_on_invoiceable"
    t.index ["payer_type", "payer_id"], name: "index_invoices_on_payee"
  end

  create_table "archived_line_items", force: :cascade do |t|
    t.string "title"
    t.integer "price", default: 0
    t.bigint "invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "refundability", null: false
    t.integer "category", default: 0, null: false
    t.boolean "priced_in", default: false, null: false
    t.integer "collected", default: 0, null: false
    t.integer "proration_reduction", default: 0, null: false
    t.date "full_refund_before_date"
    t.index ["invoice_id"], name: "index_archived_line_items_on_invoice_id"
  end

  create_table "archived_policy_premia", force: :cascade do |t|
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
    t.index ["billing_strategy_id"], name: "index_archived_policy_premia_on_billing_strategy_id"
    t.index ["commission_strategy_id"], name: "index_archived_policy_premia_on_commission_strategy_id"
    t.index ["policy_id"], name: "index_archived_policy_premia_on_policy_id"
    t.index ["policy_quote_id"], name: "index_archived_policy_premia_on_policy_quote_id"
  end

  create_table "archived_policy_premium_fees", force: :cascade do |t|
    t.bigint "policy_premium_id"
    t.bigint "fee_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fee_id"], name: "index_archived_policy_premium_fees_on_fee_id"
    t.index ["policy_premium_id"], name: "index_archived_policy_premium_fees_on_policy_premium_id"
  end

  create_table "archived_refunds", force: :cascade do |t|
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
    t.index ["charge_id"], name: "index_archived_refunds_on_charge_id"
    t.index ["status"], name: "refund_status"
    t.index ["stripe_id"], name: "refund_stripe_id"
  end

  create_table "assignments", force: :cascade do |t|
    t.boolean "primary"
    t.bigint "staff_id"
    t.string "assignable_type"
    t.bigint "assignable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignable_type", "assignable_id"], name: "index_assignments_on_assignable"
    t.index ["staff_id"], name: "index_assignments_on_staff_id"
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
    t.string "carrier_code"
    t.index ["agency_id"], name: "index_billing_strategies_on_agency_id"
    t.index ["carrier_id"], name: "index_billing_strategies_on_carrier_id"
    t.index ["policy_type_id"], name: "index_billing_strategies_on_policy_type_id"
  end

  create_table "branding_profile_attributes", force: :cascade do |t|
    t.string "name"
    t.text "value"
    t.string "attribute_type"
    t.bigint "branding_profile_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branding_profile_id"], name: "index_branding_profile_attributes_on_branding_profile_id"
  end

  create_table "branding_profiles", force: :cascade do |t|
    t.string "url"
    t.boolean "default", default: false, null: false
    t.jsonb "styles"
    t.string "profileable_type"
    t.bigint "profileable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "logo_url"
    t.string "footer_logo_url"
    t.string "subdomain"
    t.boolean "global_default", default: false, null: false
    t.string "logo_jpeg_url"
    t.boolean "enabled", default: true
    t.index ["profileable_type", "profileable_id"], name: "index_branding_profiles_on_profileable"
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
    t.jsonb "zip_code_blacklist", default: {}
    t.bigint "carrier_agency_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_agency_id"], name: "index_carrier_agency_authorizations_on_carrier_agency_id"
    t.index ["policy_type_id"], name: "index_carrier_agency_authorizations_on_policy_type_id"
  end

  create_table "carrier_agency_policy_types", force: :cascade do |t|
    t.bigint "carrier_agency_id"
    t.bigint "policy_type_id"
    t.bigint "commission_strategy_id", null: false
    t.string "collector_type"
    t.bigint "collector_id"
    t.index ["carrier_agency_id"], name: "index_carrier_agency_policy_types_on_carrier_agency_id"
    t.index ["collector_type", "collector_id"], name: "index_capt_on_collector"
    t.index ["commission_strategy_id"], name: "index_carrier_agency_policy_types_on_commission_strategy_id"
    t.index ["policy_type_id"], name: "index_carrier_agency_policy_types_on_policy_type_id"
  end

  create_table "carrier_class_codes", force: :cascade do |t|
    t.integer "external_id"
    t.string "major_category"
    t.string "sub_category"
    t.string "class_code"
    t.boolean "appetite", default: false
    t.string "search_value"
    t.string "sic_code"
    t.string "eq"
    t.string "eqsl"
    t.string "industry_program"
    t.string "naics_code"
    t.string "state_code"
    t.boolean "enabled", default: false
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id"], name: "index_carrier_class_codes_on_carrier_id"
    t.index ["class_code"], name: "index_carrier_class_codes_on_class_code"
    t.index ["policy_type_id"], name: "index_carrier_class_codes_on_policy_type_id"
  end

  create_table "carrier_insurable_profiles", force: :cascade do |t|
    t.jsonb "traits", default: {}
    t.jsonb "data", default: {}
    t.bigint "carrier_id"
    t.bigint "insurable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_carrier_id"
    t.index ["carrier_id", "external_carrier_id"], name: "carrier_external_carrier_id", unique: true
    t.index ["carrier_id"], name: "index_carrier_insurable_profiles_on_carrier_id"
    t.index ["insurable_id"], name: "index_carrier_insurable_profiles_on_insurable_id"
  end

  create_table "carrier_insurable_types", force: :cascade do |t|
    t.jsonb "profile_traits", default: {}
    t.jsonb "profile_data", default: {}
    t.boolean "enabled", default: false, null: false
    t.bigint "carrier_id"
    t.bigint "insurable_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id"], name: "index_carrier_insurable_types_on_carrier_id"
    t.index ["insurable_type_id"], name: "index_carrier_insurable_types_on_insurable_type_id"
  end

  create_table "carrier_policy_type_availabilities", force: :cascade do |t|
    t.integer "state"
    t.boolean "available", default: false, null: false
    t.jsonb "zip_code_blacklist", default: {}
    t.bigint "carrier_policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_policy_type_id"], name: "index_carrier_policy_availability"
  end

  create_table "carrier_policy_types", force: :cascade do |t|
    t.jsonb "policy_defaults", default: {"options"=>{}, "deductibles"=>{}, "coverage_limits"=>{}}
    t.jsonb "application_fields", default: []
    t.jsonb "application_questions", default: []
    t.boolean "application_required", default: false, null: false
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_days_for_full_refund", default: 31, null: false
    t.integer "days_late_before_cancellation", default: 30, null: false
    t.bigint "commission_strategy_id", null: false
    t.string "premium_proration_calculation", default: "per_payment_term", null: false
    t.boolean "premium_proration_refunds_allowed", default: true, null: false
    t.index ["carrier_id"], name: "index_carrier_policy_types_on_carrier_id"
    t.index ["commission_strategy_id"], name: "index_carrier_policy_types_on_commission_strategy_id"
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
    t.bigint "commission_strategy_id"
    t.index ["commission_strategy_id"], name: "index_carriers_on_commission_strategy_id"
  end

  create_table "change_requests", force: :cascade do |t|
    t.text "reason"
    t.integer "customized_action", default: 0
    t.string "method"
    t.string "field"
    t.string "current_value"
    t.string "new_value"
    t.integer "status", default: 0
    t.datetime "status_changed_on"
    t.bigint "staff_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "changeable_type"
    t.integer "requestable_id"
    t.string "requestable_type"
    t.integer "changeable_id"
    t.index ["staff_id"], name: "index_change_requests_on_staff_id"
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
    t.integer "type_of_loss", default: 0, null: false
    t.text "staff_notes"
    t.index ["claimant_type", "claimant_id"], name: "index_claims_on_claimant"
    t.index ["insurable_id"], name: "index_claims_on_insurable_id"
    t.index ["policy_id"], name: "index_claims_on_policy_id"
  end

  create_table "commission_items", force: :cascade do |t|
    t.integer "amount", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "commission_id"
    t.string "commissionable_type"
    t.bigint "commissionable_id"
    t.string "reason_type"
    t.bigint "reason_id"
    t.bigint "policy_quote_id"
    t.bigint "policy_id"
    t.integer "analytics_category", default: 0, null: false
    t.integer "parent_payment_total"
    t.index ["commission_id"], name: "index_commission_items_on_commission_id"
    t.index ["commissionable_type", "commissionable_id"], name: "index_commision_items_on_commissionable"
    t.index ["policy_id"], name: "index_commission_items_on_policy_id"
    t.index ["policy_quote_id"], name: "index_commission_items_on_policy_quote_id"
    t.index ["reason_type", "reason_id"], name: "index_commission_items_on_reason"
  end

  create_table "commission_strategies", force: :cascade do |t|
    t.string "title", null: false
    t.decimal "percentage", precision: 5, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recipient_type"
    t.bigint "recipient_id"
    t.bigint "commission_strategy_id"
    t.index ["commission_strategy_id"], name: "index_commission_strategies_on_commission_strategy_id"
    t.index ["recipient_type", "recipient_id"], name: "index_commission_strategies_on_recipient"
  end

  create_table "commissions", force: :cascade do |t|
    t.integer "status", null: false
    t.integer "total", default: 0, null: false
    t.boolean "true_negative_payout", default: false, null: false
    t.integer "payout_method", default: 0, null: false
    t.string "error_info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recipient_type"
    t.bigint "recipient_id"
    t.string "stripe_transfer_id"
    t.jsonb "payout_data"
    t.text "payout_notes"
    t.datetime "approved_at"
    t.datetime "marked_paid_at"
    t.bigint "approved_by_id"
    t.bigint "marked_paid_by_id"
    t.index ["approved_by_id"], name: "index_commissions_on_approved_by_id"
    t.index ["marked_paid_by_id"], name: "index_commissions_on_marked_paid_by_id"
    t.index ["recipient_type", "recipient_id"], name: "index_commissions_on_recipient"
  end

  create_table "disputes", force: :cascade do |t|
    t.string "stripe_id", null: false
    t.integer "amount", null: false
    t.integer "stripe_reason", null: false
    t.integer "status", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "stripe_charge_id"
    t.index ["stripe_charge_id"], name: "index_disputes_on_stripe_charge_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "verb", default: 0
    t.integer "format", default: 0
    t.integer "interface", default: 0
    t.integer "status", default: 0
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
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable"
  end

  create_table "external_charges", force: :cascade do |t|
    t.boolean "processed", default: false, null: false
    t.boolean "invoice_aware", default: false, null: false
    t.integer "status", null: false
    t.datetime "status_changed_at"
    t.string "external_reference", null: false
    t.integer "amount", null: false
    t.datetime "collected_at", null: false
    t.bigint "invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_external_charges_on_invoice_id"
  end

  create_table "faq_questions", force: :cascade do |t|
    t.text "question"
    t.text "answer"
    t.integer "faq_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "question_order", default: 0
    t.index ["faq_id"], name: "index_faq_questions_on_faq_id"
  end

  create_table "faqs", force: :cascade do |t|
    t.string "title"
    t.integer "branding_profile_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "faq_order", default: 0
    t.integer "language", default: 0
    t.index ["branding_profile_id"], name: "index_faqs_on_branding_profile_id"
  end

  create_table "fees", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.decimal "amount", default: "0.0", null: false
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
    t.boolean "hidden", default: false, null: false
    t.index ["assignable_type", "assignable_id"], name: "index_fees_on_assignable"
    t.index ["ownerable_type", "ownerable_id"], name: "index_fees_on_ownerable"
  end

  create_table "global_agency_permissions", force: :cascade do |t|
    t.jsonb "permissions", default: {}
    t.bigint "agency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_global_agency_permissions_on_agency_id"
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
    t.string "author"
    t.index ["authorable_type", "authorable_id"], name: "index_histories_on_authorable"
    t.index ["recordable_type", "recordable_id"], name: "index_histories_on_recordable"
  end

  create_table "insurable_data", force: :cascade do |t|
    t.bigint "insurable_id"
    t.integer "uninsured_units"
    t.integer "total_units"
    t.integer "expiring_policies"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["insurable_id"], name: "index_insurable_data_on_insurable_id"
  end

  create_table "insurable_geographical_categories", force: :cascade do |t|
    t.integer "state"
    t.string "counties", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "zip_codes", array: true
    t.string "cities", array: true
    t.bigint "insurable_id"
    t.integer "special_usage"
    t.string "special_designation"
    t.jsonb "special_settings"
    t.index ["insurable_id"], name: "index_insurable_geographical_categories_on_insurable_id"
  end

  create_table "insurable_rate_configurations", force: :cascade do |t|
    t.jsonb "carrier_info", default: {}, null: false
    t.string "configurable_type"
    t.bigint "configurable_id"
    t.string "configurer_type"
    t.bigint "configurer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "configuration", default: {}, null: false
    t.jsonb "rates", default: {}, null: false
    t.bigint "carrier_policy_type_id", null: false
    t.index ["carrier_policy_type_id"], name: "index_irc_on_cpt"
    t.index ["configurable_type", "configurable_id"], name: "index_irc_configurable"
    t.index ["configurer_type", "configurer_id"], name: "index_irc_configurer"
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
    t.boolean "enabled", default: true
    t.boolean "mandatory", default: false
    t.index ["agency_id"], name: "index_insurable_rates_on_agency_id"
    t.index ["carrier_id"], name: "index_insurable_rates_on_carrier_id"
    t.index ["insurable_id"], name: "index_insurable_rates_on_insurable_id"
  end

  create_table "insurable_types", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.integer "category"
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "policy_type_ids", default: [], null: false, array: true
    t.boolean "occupiable", default: false
  end

  create_table "insurables", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.boolean "enabled", default: false
    t.bigint "account_id"
    t.bigint "insurable_type_id"
    t.bigint "insurable_id"
    t.integer "category", default: 0
    t.boolean "covered", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "agency_id"
    t.bigint "policy_type_ids", default: [], null: false, array: true
    t.boolean "preferred_ho4", default: false, null: false
    t.boolean "confirmed", default: true, null: false
    t.boolean "occupied", default: false
    t.jsonb "expanded_covered", default: {}, null: false
    t.jsonb "preferred", default: {}
    t.boolean "additional_interest", default: false
    t.string "additional_interest_name"
    t.index ["account_id"], name: "index_insurables_on_account_id"
    t.index ["agency_id"], name: "index_insurables_on_agency_id"
    t.index ["insurable_id"], name: "index_insurables_on_insurable_id"
    t.index ["insurable_type_id"], name: "index_insurables_on_insurable_type_id"
    t.index ["policy_type_ids"], name: "insurable_ptids_gin_index", using: :gin
    t.index ["preferred_ho4"], name: "index_insurables_on_preferred_ho4"
  end

  create_table "integration_profiles", force: :cascade do |t|
    t.string "external_id"
    t.jsonb "configuration", default: {}
    t.boolean "enabled", default: false
    t.bigint "integration_id"
    t.string "profileable_type"
    t.bigint "profileable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_context"
    t.index ["integration_id", "external_context", "external_id"], name: "index_integration_profiles_on_externals", unique: true
    t.index ["integration_id"], name: "index_integration_profiles_on_integration_id"
    t.index ["profileable_type", "profileable_id"], name: "index_integration_profiles_on_profileable"
  end

  create_table "integrations", force: :cascade do |t|
    t.string "external_id"
    t.jsonb "credentials", default: {}
    t.jsonb "configuration", default: {}
    t.boolean "enabled", default: false
    t.string "integratable_type"
    t.bigint "integratable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "provider", default: 0
    t.index ["external_id"], name: "index_integrations_on_external_id", unique: true
    t.index ["integratable_type", "integratable_id"], name: "index_integrations_on_integratable"
  end

  create_table "invoices", force: :cascade do |t|
    t.string "number", null: false
    t.text "description"
    t.date "available_date", null: false
    t.date "due_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "external", default: false, null: false
    t.integer "status", null: false
    t.boolean "under_review", default: false, null: false
    t.integer "pending_charge_count", default: 0, null: false
    t.integer "pending_dispute_count", default: 0, null: false
    t.jsonb "error_info", default: [], null: false
    t.boolean "was_missed", default: false, null: false
    t.datetime "was_missed_at"
    t.boolean "autosend_status_change_notifications", default: true, null: false
    t.integer "original_total_due", default: 0, null: false
    t.integer "total_due", default: 0, null: false
    t.integer "total_payable", default: 0, null: false
    t.integer "total_reducing", default: 0, null: false
    t.integer "total_pending", default: 0, null: false
    t.integer "total_received", default: 0, null: false
    t.integer "total_undistributable", default: 0, null: false
    t.string "invoiceable_type"
    t.bigint "invoiceable_id"
    t.string "payer_type"
    t.bigint "payer_id"
    t.string "collector_type"
    t.bigint "collector_id"
    t.bigint "archived_invoice_id"
    t.datetime "status_changed"
    t.index ["archived_invoice_id"], name: "index_invoices_on_archived_invoice_id"
    t.index ["collector_type", "collector_id"], name: "index_invoices_on_collector"
    t.index ["invoiceable_type", "invoiceable_id"], name: "index_invoices_on_invoiceable_type_and_invoiceable_id"
    t.index ["payer_type", "payer_id"], name: "index_invoices_on_payer"
  end

  create_table "lead_events", force: :cascade do |t|
    t.jsonb "data"
    t.string "tag"
    t.float "latitude"
    t.float "longitude"
    t.bigint "lead_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "policy_type_id"
    t.bigint "agency_id"
    t.integer "branding_profile_id"
    t.index ["agency_id"], name: "index_lead_events_on_agency_id"
    t.index ["lead_id"], name: "index_lead_events_on_lead_id"
    t.index ["policy_type_id"], name: "index_lead_events_on_policy_type_id"
  end

  create_table "leads", force: :cascade do |t|
    t.string "email"
    t.string "identifier"
    t.bigint "user_id"
    t.string "labels", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0
    t.datetime "last_visit"
    t.string "last_visited_page"
    t.integer "tracking_url_id"
    t.integer "agency_id"
    t.boolean "archived", default: false
    t.integer "account_id"
    t.integer "branding_profile_id"
    t.index ["email"], name: "index_leads_on_email"
    t.index ["identifier"], name: "index_leads_on_identifier", unique: true
    t.index ["tracking_url_id"], name: "index_leads_on_tracking_url_id"
    t.index ["user_id"], name: "index_leads_on_user_id"
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
    t.boolean "primary", default: false
    t.bigint "lease_id"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "lessee", default: true, null: false
    t.index ["lease_id"], name: "index_lease_users_on_lease_id"
    t.index ["user_id"], name: "index_lease_users_on_user_id"
  end

  create_table "leases", force: :cascade do |t|
    t.string "reference"
    t.date "start_date"
    t.date "end_date"
    t.integer "status", default: 0
    t.boolean "covered", default: false
    t.bigint "lease_type_id"
    t.bigint "insurable_id"
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "expanded_covered", default: {}
    t.index ["account_id"], name: "index_leases_on_account_id"
    t.index ["insurable_id"], name: "index_leases_on_insurable_id"
    t.index ["lease_type_id"], name: "index_leases_on_lease_type_id"
    t.index ["reference"], name: "lease_reference", unique: true
  end

  create_table "line_item_changes", force: :cascade do |t|
    t.integer "field_changed", null: false
    t.integer "amount", null: false
    t.integer "new_value", null: false
    t.boolean "handled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "line_item_id"
    t.string "reason_type"
    t.bigint "reason_id"
    t.string "handler_type"
    t.bigint "handler_id"
    t.string "error_info"
    t.integer "analytics_category", default: 0, null: false
    t.index ["handler_type", "handler_id"], name: "index_line_item_changes_on_handler"
    t.index ["line_item_id"], name: "index_line_item_changes_on_line_item_id"
    t.index ["reason_type", "reason_id"], name: "index_line_item_changes_on_reason"
  end

  create_table "line_item_reductions", force: :cascade do |t|
    t.string "reason", null: false
    t.integer "refundability", null: false
    t.integer "proration_interaction", default: 0, null: false
    t.integer "amount_interpretation", default: 0, null: false
    t.integer "amount", null: false
    t.integer "amount_successful", default: 0, null: false
    t.integer "amount_refunded", default: 0, null: false
    t.boolean "pending", default: true, null: false
    t.integer "stripe_refund_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "line_item_id"
    t.bigint "dispute_id"
    t.bigint "refund_id"
    t.index ["dispute_id"], name: "index_line_item_reductions_on_dispute_id"
    t.index ["line_item_id"], name: "index_line_item_reductions_on_line_item_id"
    t.index ["refund_id"], name: "index_line_item_reductions_on_refund_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.string "title", null: false
    t.boolean "priced_in", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "original_total_due", null: false
    t.integer "total_due", null: false
    t.integer "total_reducing", default: 0, null: false
    t.integer "total_received", default: 0, null: false
    t.integer "preproration_total_due", null: false
    t.integer "duplicatable_reduction_total", default: 0, null: false
    t.string "chargeable_type"
    t.bigint "chargeable_id"
    t.bigint "invoice_id"
    t.integer "analytics_category", default: 0, null: false
    t.bigint "policy_quote_id"
    t.bigint "policy_id"
    t.bigint "archived_line_item_id"
    t.boolean "hidden", default: false, null: false
    t.index ["archived_line_item_id"], name: "index_line_items_on_archived_line_item_id"
    t.index ["chargeable_type", "chargeable_id"], name: "index_line_items_on_chargeable"
    t.index ["invoice_id"], name: "index_line_items_on_invoice_id"
    t.index ["policy_id"], name: "index_line_items_on_policy_id"
    t.index ["policy_quote_id"], name: "index_line_items_on_policy_quote_id"
  end

  create_table "login_activities", force: :cascade do |t|
    t.string "scope"
    t.string "strategy"
    t.string "identity"
    t.boolean "success"
    t.string "failure_reason"
    t.string "user_type"
    t.bigint "user_id"
    t.string "context"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "city"
    t.string "region"
    t.string "country"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at"
    t.string "client"
    t.integer "expiry"
    t.boolean "active", default: true
    t.index ["identity"], name: "index_login_activities_on_identity"
    t.index ["ip"], name: "index_login_activities_on_ip"
    t.index ["user_type", "user_id"], name: "index_login_activities_on_user"
  end

  create_table "master_policy_configurations", force: :cascade do |t|
    t.integer "program_type", default: 0
    t.integer "grace_period", default: 0
    t.string "integration_charge_code"
    t.boolean "prorate_charges", default: false
    t.boolean "auto_post_charges", default: true
    t.boolean "consolidate_billing", default: true
    t.datetime "program_start_date"
    t.integer "program_delay", default: 0
    t.integer "placement_cost", default: 0
    t.integer "force_placement_cost"
    t.bigint "carrier_policy_type_id", null: false
    t.string "configurable_type", null: false
    t.bigint "configurable_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "enabled", default: false
    t.index ["carrier_policy_type_id", "configurable_type", "configurable_id"], name: "index_cpt_and_conf_on_mpc", unique: true
    t.index ["configurable_type", "configurable_id"], name: "index_master_policy_configurations_on_configurable"
  end

  create_table "model_errors", force: :cascade do |t|
    t.string "model_type"
    t.bigint "model_id"
    t.string "kind"
    t.jsonb "information"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_type", "model_id"], name: "index_model_errors_on_model"
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
    t.index ["noteable_type", "noteable_id"], name: "index_notes_on_noteable"
    t.index ["staff_id"], name: "index_notes_on_staff_id"
  end

  create_table "notification_settings", force: :cascade do |t|
    t.string "action"
    t.boolean "enabled", default: false, null: false
    t.string "notifyable_type"
    t.bigint "notifyable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_notification_settings_on_action"
    t.index ["notifyable_type", "notifyable_id"], name: "notification_settings_notifyable_index"
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
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
  end

  create_table "pages", force: :cascade do |t|
    t.text "content"
    t.string "title"
    t.bigint "agency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "branding_profile_id"
    t.jsonb "styles"
    t.index ["agency_id"], name: "index_pages_on_agency_id"
    t.index ["branding_profile_id"], name: "index_pages_on_branding_profile_id"
  end

  create_table "payment_profiles", force: :cascade do |t|
    t.string "source_id"
    t.integer "source_type"
    t.string "fingerprint"
    t.boolean "default_profile", default: false
    t.boolean "active"
    t.boolean "verified"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payer_type"
    t.bigint "payer_id"
    t.jsonb "card"
    t.index ["payer_type", "payer_id"], name: "index_payment_profiles_on_payer_type_and_payer_id"
  end

  create_table "policies", force: :cascade do |t|
    t.string "number"
    t.date "effective_date"
    t.date "expiration_date"
    t.boolean "auto_renew", default: false, null: false
    t.date "last_renewed_on"
    t.integer "renew_count"
    t.integer "billing_status"
    t.integer "billing_dispute_count", default: 0, null: false
    t.date "billing_behind_since"
    t.string "cancellation_date"
    t.integer "status"
    t.datetime "status_changed_on"
    t.integer "billing_dispute_status", default: 0, null: false
    t.boolean "billing_enabled", default: false, null: false
    t.boolean "system_purchased", default: false, null: false
    t.boolean "serviceable", default: false, null: false
    t.boolean "has_outstanding_refund", default: false, null: false
    t.jsonb "system_data", default: {}
    t.bigint "agency_id"
    t.bigint "account_id"
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "policy_in_system"
    t.boolean "auto_pay"
    t.date "last_payment_date"
    t.date "next_payment_date"
    t.bigint "policy_group_id"
    t.boolean "declined"
    t.string "address"
    t.string "out_of_system_carrier_title"
    t.bigint "policy_id"
    t.integer "cancellation_reason"
    t.integer "branding_profile_id"
    t.boolean "marked_for_cancellation", default: false, null: false
    t.string "marked_for_cancellation_info"
    t.datetime "marked_cancellation_time"
    t.string "marked_cancellation_reason"
    t.integer "document_status", default: 0
    t.boolean "force_placed"
    t.index ["account_id"], name: "index_policies_on_account_id"
    t.index ["agency_id"], name: "index_policies_on_agency_id"
    t.index ["carrier_id"], name: "index_policies_on_carrier_id"
    t.index ["number"], name: "index_policies_on_number", unique: true
    t.index ["policy_group_id"], name: "index_policies_on_policy_group_id"
    t.index ["policy_id"], name: "index_policies_on_policy_id"
    t.index ["policy_type_id"], name: "index_policies_on_policy_type_id"
  end

  create_table "policy_application_answers", force: :cascade do |t|
    t.jsonb "data", default: {"answer"=>nil, "desired"=>nil, "options"=>[]}
    t.integer "section", default: 0, null: false
    t.bigint "policy_application_field_id"
    t.bigint "policy_application_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_application_field_id"], name: "index_policy_application_answers_on_policy_application_field_id"
    t.index ["policy_application_id"], name: "index_policy_application_answers_on_policy_application_id"
  end

  create_table "policy_application_fields", force: :cascade do |t|
    t.string "title"
    t.integer "section"
    t.integer "answer_type"
    t.string "default_answer"
    t.string "desired_answer"
    t.jsonb "answer_options"
    t.boolean "enabled"
    t.integer "order_position"
    t.bigint "policy_application_field_id"
    t.bigint "policy_type_id"
    t.bigint "carrier_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id"], name: "index_policy_application_fields_on_carrier_id"
    t.index ["policy_application_field_id"], name: "index_policy_application_fields_on_policy_application_field_id"
    t.index ["policy_type_id"], name: "index_policy_application_fields_on_policy_type_id"
  end

  create_table "policy_application_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "policy_applications_count"
    t.integer "status", default: 0
    t.bigint "account_id"
    t.bigint "agency_id"
    t.date "effective_date"
    t.date "expiration_date"
    t.boolean "auto_renew", default: false
    t.boolean "auto_pay", default: false
    t.bigint "billing_strategy_id"
    t.bigint "policy_group_id"
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.index ["account_id"], name: "index_policy_application_groups_on_account_id"
    t.index ["agency_id"], name: "index_policy_application_groups_on_agency_id"
    t.index ["billing_strategy_id"], name: "index_policy_application_groups_on_billing_strategy_id"
    t.index ["carrier_id"], name: "index_policy_application_groups_on_carrier_id"
    t.index ["policy_group_id"], name: "index_policy_application_groups_on_policy_group_id"
    t.index ["policy_type_id"], name: "index_policy_application_groups_on_policy_type_id"
  end

  create_table "policy_applications", force: :cascade do |t|
    t.string "reference"
    t.string "external_reference"
    t.date "effective_date"
    t.date "expiration_date"
    t.integer "status", default: 0, null: false
    t.datetime "status_updated_on"
    t.jsonb "fields", default: []
    t.jsonb "questions", default: []
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.bigint "agency_id"
    t.bigint "account_id"
    t.bigint "policy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "billing_strategy_id"
    t.boolean "auto_renew", default: true
    t.boolean "auto_pay", default: true
    t.bigint "policy_application_group_id"
    t.jsonb "coverage_selections", default: {}, null: false
    t.jsonb "extra_settings", default: {}
    t.jsonb "resolver_info"
    t.bigint "tag_ids", default: [], null: false, array: true
    t.jsonb "tagging_data"
    t.string "error_message"
    t.integer "branding_profile_id"
    t.string "internal_error_message"
    t.index ["account_id"], name: "index_policy_applications_on_account_id"
    t.index ["agency_id"], name: "index_policy_applications_on_agency_id"
    t.index ["billing_strategy_id"], name: "index_policy_applications_on_billing_strategy_id"
    t.index ["carrier_id"], name: "index_policy_applications_on_carrier_id"
    t.index ["policy_application_group_id"], name: "index_policy_applications_on_policy_application_group_id"
    t.index ["policy_id"], name: "index_policy_applications_on_policy_id"
    t.index ["policy_type_id"], name: "index_policy_applications_on_policy_type_id"
    t.index ["tag_ids"], name: "policy_application_tag_ids_index", using: :gin
  end

  create_table "policy_coverages", force: :cascade do |t|
    t.string "title"
    t.string "designation"
    t.integer "limit", default: 0
    t.integer "deductible", default: 0
    t.bigint "policy_id"
    t.bigint "policy_application_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "enabled", default: false, null: false
    t.integer "special_deductible"
    t.integer "occurrence_limit"
    t.boolean "is_carrier_fee", default: false
    t.integer "aggregate_limit"
    t.integer "external_payments_limit"
    t.integer "limit_used"
    t.index ["policy_application_id"], name: "index_policy_coverages_on_policy_application_id"
    t.index ["policy_id"], name: "index_policy_coverages_on_policy_id"
  end

  create_table "policy_group_premia", force: :cascade do |t|
    t.integer "base", default: 0
    t.integer "taxes", default: 0
    t.integer "total_fees", default: 0
    t.integer "total", default: 0
    t.integer "estimate"
    t.integer "calculation_base", default: 0
    t.integer "deposit_fees", default: 0
    t.integer "amortized_fees", default: 0
    t.integer "special_premium", default: 0
    t.integer "integer", default: 0
    t.boolean "include_special_premium", default: false
    t.boolean "boolean", default: false
    t.integer "carrier_base", default: 0
    t.integer "unearned_premium", default: 0
    t.boolean "enabled", default: false, null: false
    t.datetime "enabled_changed"
    t.bigint "policy_group_quote_id"
    t.bigint "billing_strategy_id"
    t.bigint "commission_strategy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "policy_group_id"
    t.boolean "only_fees_internal", default: false
    t.integer "external_fees", default: 0
    t.index ["billing_strategy_id"], name: "index_policy_group_premia_on_billing_strategy_id"
    t.index ["commission_strategy_id"], name: "index_policy_group_premia_on_commission_strategy_id"
    t.index ["policy_group_id"], name: "index_policy_group_premia_on_policy_group_id"
    t.index ["policy_group_quote_id"], name: "index_policy_group_premia_on_policy_group_quote_id"
  end

  create_table "policy_group_quotes", force: :cascade do |t|
    t.string "reference"
    t.string "external_reference"
    t.integer "status"
    t.datetime "status_updated_on"
    t.integer "premium"
    t.integer "tax"
    t.integer "est_fees"
    t.integer "total_premium"
    t.bigint "agency_id"
    t.bigint "account_id"
    t.bigint "policy_application_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "policy_group_id"
    t.index ["account_id"], name: "index_policy_group_quotes_on_account_id"
    t.index ["agency_id"], name: "index_policy_group_quotes_on_agency_id"
    t.index ["policy_application_group_id"], name: "index_policy_group_quotes_on_policy_application_group_id"
    t.index ["policy_group_id"], name: "index_policy_group_quotes_on_policy_group_id"
  end

  create_table "policy_groups", force: :cascade do |t|
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
    t.date "last_payment_date"
    t.date "next_payment_date"
    t.boolean "policy_in_system"
    t.boolean "auto_pay"
    t.bigint "agency_id"
    t.bigint "account_id"
    t.bigint "carrier_id"
    t.bigint "policy_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_policy_groups_on_account_id"
    t.index ["agency_id"], name: "index_policy_groups_on_agency_id"
    t.index ["carrier_id"], name: "index_policy_groups_on_carrier_id"
    t.index ["number"], name: "index_policy_groups_on_number", unique: true
    t.index ["policy_type_id"], name: "index_policy_groups_on_policy_type_id"
  end

  create_table "policy_insurables", force: :cascade do |t|
    t.integer "value", default: 0
    t.boolean "primary", default: false
    t.boolean "current", default: false
    t.bigint "policy_id"
    t.bigint "policy_application_id"
    t.bigint "insurable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "auto_assign", default: false
    t.index ["insurable_id"], name: "index_policy_insurables_on_insurable_id"
    t.index ["policy_application_id"], name: "index_policy_insurables_on_policy_application_id"
    t.index ["policy_id"], name: "index_policy_insurables_on_policy_id"
  end

  create_table "policy_premia", force: :cascade do |t|
    t.integer "total_premium", default: 0, null: false
    t.integer "total_fee", default: 0, null: false
    t.integer "total_tax", default: 0, null: false
    t.integer "total", default: 0, null: false
    t.boolean "prorated", default: false, null: false
    t.datetime "prorated_last_moment"
    t.datetime "prorated_first_moment"
    t.boolean "force_no_refunds", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "error_info"
    t.bigint "policy_quote_id"
    t.bigint "policy_id"
    t.bigint "commission_strategy_id"
    t.bigint "archived_policy_premium_id"
    t.integer "total_hidden_fee", default: 0, null: false
    t.integer "total_hidden_tax", default: 0, null: false
    t.index ["archived_policy_premium_id"], name: "index_policy_premia_on_archived_policy_premium_id"
    t.index ["commission_strategy_id"], name: "index_policy_premia_on_commission_strategy_id"
    t.index ["policy_id"], name: "index_policy_premia_on_policy_id"
    t.index ["policy_quote_id"], name: "index_policy_premia_on_policy_quote_id"
  end

  create_table "policy_premium_item_commissions", force: :cascade do |t|
    t.integer "status", null: false
    t.integer "payability", null: false
    t.integer "total_expected", null: false
    t.integer "total_received", default: 0, null: false
    t.integer "total_commission", default: 0, null: false
    t.decimal "percentage", precision: 5, scale: 2, null: false
    t.integer "payment_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "policy_premium_item_id"
    t.string "recipient_type"
    t.bigint "recipient_id"
    t.bigint "commission_strategy_id"
    t.index ["commission_strategy_id"], name: "index_policy_premium_item_commissions_on_commission_strategy_id"
    t.index ["policy_premium_item_id"], name: "index_policy_premium_item_commissions_on_policy_premium_item_id"
    t.index ["recipient_type", "recipient_id"], name: "index_policy_premium_item_commission_on_recipient"
  end

  create_table "policy_premium_item_payment_terms", force: :cascade do |t|
    t.integer "weight", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "policy_premium_payment_term_id"
    t.bigint "policy_premium_item_id"
    t.index ["policy_premium_item_id"], name: "index_ppipt_on_ppi"
    t.index ["policy_premium_payment_term_id"], name: "index_ppipt_on_pppt_id"
  end

  create_table "policy_premium_item_transaction_memberships", force: :cascade do |t|
    t.bigint "policy_premium_item_transaction_id"
    t.string "member_type"
    t.bigint "member_id"
    t.index ["member_type", "member_id"], name: "index_ppitms_on_member"
    t.index ["policy_premium_item_transaction_id"], name: "index_ppitms_on_ppit"
  end

  create_table "policy_premium_item_transactions", force: :cascade do |t|
    t.boolean "pending", default: true, null: false
    t.datetime "create_commission_items_at", null: false
    t.integer "amount", null: false
    t.jsonb "error_info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recipient_type"
    t.bigint "recipient_id"
    t.string "commissionable_type"
    t.bigint "commissionable_id"
    t.string "reason_type"
    t.bigint "reason_id"
    t.bigint "policy_premium_item_id"
    t.integer "analytics_category", default: 0, null: false
    t.index ["commissionable_type", "commissionable_id"], name: "index_ppits_on_commissionable"
    t.index ["pending", "create_commission_items_at"], name: "index_ppits_on_pending_and_ccia"
    t.index ["policy_premium_item_id"], name: "index_ppits_on_ppi"
    t.index ["reason_type", "reason_id"], name: "index_ppits_on_reason"
    t.index ["recipient_type", "recipient_id"], name: "index_ppits_on_recipient"
  end

  create_table "policy_premium_items", force: :cascade do |t|
    t.string "title", null: false
    t.integer "category", null: false
    t.integer "rounding_error_distribution", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "original_total_due", null: false
    t.integer "total_due", null: false
    t.integer "total_received", default: 0, null: false
    t.boolean "proration_pending", default: false, null: false
    t.integer "proration_calculation", null: false
    t.boolean "proration_refunds_allowed", null: false
    t.integer "commission_calculation", default: 0, null: false
    t.integer "commission_creation_delay_hours"
    t.bigint "policy_premium_id"
    t.string "recipient_type"
    t.bigint "recipient_id"
    t.string "collector_type"
    t.bigint "collector_id"
    t.string "collection_plan_type"
    t.bigint "collection_plan_id"
    t.bigint "fee_id"
    t.boolean "hidden", default: false, null: false
    t.index ["collection_plan_type", "collection_plan_id"], name: "index_policy_premium_items_on_cp"
    t.index ["collector_type", "collector_id"], name: "index_policy_premium_items_on_collector"
    t.index ["fee_id"], name: "index_policy_premium_items_on_fee_id"
    t.index ["policy_premium_id"], name: "index_policy_premium_items_on_policy_premium_id"
    t.index ["recipient_type", "recipient_id"], name: "index_policy_premium_items_on_recipient"
  end

  create_table "policy_premium_payment_terms", force: :cascade do |t|
    t.datetime "original_first_moment", null: false
    t.datetime "original_last_moment", null: false
    t.datetime "first_moment", null: false
    t.datetime "last_moment", null: false
    t.decimal "unprorated_proportion", default: "1.0", null: false
    t.boolean "prorated", default: false, null: false
    t.integer "time_resolution", default: 0, null: false
    t.boolean "cancelled", default: false, null: false
    t.integer "default_weight"
    t.string "term_group"
    t.date "invoice_available_date_override"
    t.date "invoice_due_date_override"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "policy_premium_id"
    t.index ["policy_premium_id"], name: "index_policy_premium_payment_terms_on_policy_premium_id"
  end

  create_table "policy_quotes", force: :cascade do |t|
    t.string "reference"
    t.string "external_reference"
    t.integer "status", default: 0
    t.datetime "status_updated_on"
    t.bigint "policy_application_id"
    t.bigint "agency_id"
    t.bigint "account_id"
    t.bigint "policy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "est_premium"
    t.string "external_id"
    t.bigint "policy_group_quote_id"
    t.jsonb "carrier_payment_data"
    t.index ["account_id"], name: "index_policy_quotes_on_account_id"
    t.index ["agency_id"], name: "index_policy_quotes_on_agency_id"
    t.index ["external_id"], name: "index_policy_quotes_on_external_id", unique: true
    t.index ["policy_application_id"], name: "index_policy_quotes_on_policy_application_id"
    t.index ["policy_group_quote_id"], name: "index_policy_quotes_on_policy_group_quote_id"
    t.index ["policy_id"], name: "index_policy_quotes_on_policy_id"
  end

  create_table "policy_rates", force: :cascade do |t|
    t.bigint "policy_id"
    t.bigint "policy_quote_id"
    t.bigint "insurable_rate_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "policy_application_id"
    t.index ["insurable_rate_id"], name: "index_policy_rates_on_insurable_rate_id"
    t.index ["policy_application_id"], name: "index_policy_rates_on_policy_application_id"
    t.index ["policy_id"], name: "index_policy_rates_on_policy_id"
    t.index ["policy_quote_id"], name: "index_policy_rates_on_policy_quote_id"
  end

  create_table "policy_types", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.string "designation"
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "master", default: false
    t.boolean "master_coverage", default: false
    t.integer "master_policy_id"
  end

  create_table "policy_users", force: :cascade do |t|
    t.boolean "primary", default: false, null: false
    t.boolean "spouse", default: false, null: false
    t.bigint "policy_application_id"
    t.bigint "policy_id"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0
    t.datetime "disputed_at"
    t.integer "dispute_status", default: 0
    t.text "dispute_reason"
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
    t.string "job_title"
    t.string "full_name"
    t.string "contact_email"
    t.string "contact_phone"
    t.date "birth_date"
    t.string "profileable_type"
    t.bigint "profileable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "gender", default: 0
    t.integer "salutation", default: 0
    t.integer "language", default: 0
    t.index ["profileable_type", "profileable_id"], name: "index_profiles_on_profileable"
  end

  create_table "refunds", force: :cascade do |t|
    t.string "refund_reasons", default: [], null: false, array: true
    t.integer "amount", default: 0, null: false
    t.integer "amount_refunded", default: 0, null: false
    t.integer "amount_returned_by_dispute", default: 0, null: false
    t.boolean "complete", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "invoice_id"
    t.index ["invoice_id"], name: "index_refunds_on_invoice_id"
  end

  create_table "reports", force: :cascade do |t|
    t.integer "duration"
    t.datetime "range_start"
    t.datetime "range_end"
    t.jsonb "data"
    t.string "reportable_type"
    t.bigint "reportable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["reportable_type", "reportable_id", "created_at"], name: "reports_index"
    t.index ["reportable_type", "reportable_id"], name: "index_reports_on_reportable"
  end

  create_table "signable_documents", force: :cascade do |t|
    t.string "title", null: false
    t.integer "document_type", null: false
    t.jsonb "document_data"
    t.integer "status", default: 0, null: false
    t.boolean "errored", default: false, null: false
    t.jsonb "error_data"
    t.datetime "signed_at"
    t.string "signer_type"
    t.bigint "signer_id"
    t.string "referent_type"
    t.bigint "referent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["referent_type", "referent_id"], name: "index_signable_documents_on_referent"
    t.index ["signer_type", "signer_id"], name: "index_signable_documents_on_signer"
    t.index ["status", "referent_type", "referent_id"], name: "signable_documents_signed_index"
  end

  create_table "staff_permissions", force: :cascade do |t|
    t.jsonb "permissions", default: {}
    t.bigint "global_agency_permission_id"
    t.bigint "staff_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["global_agency_permission_id"], name: "index_staff_permissions_on_global_agency_permission_id"
    t.index ["staff_id"], name: "index_staff_permissions_on_staff_id"
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
    t.index ["invited_by_type", "invited_by_id"], name: "index_staffs_on_invited_by"
    t.index ["organizable_type", "organizable_id"], name: "index_staffs_on_organizable"
    t.index ["reset_password_token"], name: "index_staffs_on_reset_password_token", unique: true
    t.index ["role"], name: "index_staffs_on_role"
    t.index ["uid", "provider"], name: "index_staffs_on_uid_and_provider", unique: true
  end

  create_table "stripe_charges", force: :cascade do |t|
    t.boolean "processed", default: false, null: false
    t.boolean "invoice_aware", default: false, null: false
    t.integer "status", default: 0, null: false
    t.datetime "status_changed_at"
    t.integer "amount", null: false
    t.integer "amount_refunded", default: 0, null: false
    t.string "source"
    t.string "customer_stripe_id"
    t.string "description"
    t.jsonb "metadata"
    t.string "stripe_id"
    t.string "error_info"
    t.jsonb "client_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "invoice_id", null: false
    t.bigint "archived_charge_id"
    t.index ["archived_charge_id"], name: "index_stripe_charges_on_archived_charge_id"
    t.index ["invoice_id"], name: "index_stripe_charges_on_invoice_id"
  end

  create_table "stripe_refunds", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "full_reasons", default: [], null: false, array: true
    t.integer "amount", null: false
    t.string "stripe_id"
    t.integer "stripe_reason"
    t.integer "stripe_status"
    t.string "failure_reason"
    t.string "receipt_number"
    t.string "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "refund_id"
    t.bigint "stripe_charge_id"
    t.index ["refund_id"], name: "index_stripe_refunds_on_refund_id"
    t.index ["stripe_charge_id"], name: "index_stripe_refunds_on_stripe_charge_id"
  end

  create_table "system_histories", force: :cascade do |t|
    t.string "field"
    t.string "previous_value_str"
    t.string "new_value_str"
    t.jsonb "system_data", default: {}
    t.string "recordable_type", null: false
    t.bigint "recordable_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["recordable_type", "recordable_id"], name: "index_system_histories_on_recordable"
  end

  create_table "tags", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_tags_on_title", unique: true
  end

  create_table "tracking_urls", force: :cascade do |t|
    t.string "landing_page"
    t.string "campaign_source"
    t.string "campaign_medium"
    t.string "campaign_term"
    t.text "campaign_content"
    t.string "campaign_name"
    t.boolean "deleted", default: false
    t.bigint "agency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "branding_profile_id"
    t.index ["agency_id"], name: "index_tracking_urls_on_agency_id"
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
    t.citext "email"
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
    t.string "stripe_id"
    t.jsonb "payment_methods"
    t.integer "current_payment_method"
    t.string "mailchimp_id"
    t.integer "mailchimp_category", default: 0
    t.string "qbe_id"
    t.boolean "has_existing_policies", default: false
    t.boolean "has_current_leases", default: false
    t.boolean "has_leases", default: false
    t.string "altuid"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["mailchimp_id"], name: "index_users_on_mailchimp_id", unique: true
    t.index ["qbe_id"], name: "index_users_on_qbe_id", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "policy_coverages", "policies"
  add_foreign_key "policy_coverages", "policy_applications"
  add_foreign_key "policy_types", "policy_types", column: "master_policy_id"
end
