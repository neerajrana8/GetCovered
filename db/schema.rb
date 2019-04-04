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

ActiveRecord::Schema.define(version: 2019_04_04_085627) do

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

  create_table "policy_types", force: :cascade do |t|
    t.string "title"
    t.integer "slug"
    t.jsonb "defaults", default: {"options"=>{}, "deductibles"=>{}, "coverage_limits"=>{}}
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["confirmation_token"], name: "index_staffs_on_confirmation_token", unique: true
    t.index ["email"], name: "index_staffs_on_email", unique: true
    t.index ["invitation_token"], name: "index_staffs_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_staffs_on_invitations_count"
    t.index ["invited_by_id"], name: "index_staffs_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_staffs_on_invited_by_type_and_invited_by_id"
    t.index ["organizable_type", "organizable_id"], name: "index_staffs_on_organizable_type_and_organizable_id"
    t.index ["reset_password_token"], name: "index_staffs_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_staffs_on_uid_and_provider", unique: true
  end

  create_table "super_admins", force: :cascade do |t|
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
    t.json "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_super_admins_on_confirmation_token", unique: true
    t.index ["email"], name: "index_super_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_super_admins_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_super_admins_on_uid_and_provider", unique: true
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
