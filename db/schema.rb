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

ActiveRecord::Schema.define(version: 2019_04_02_210253) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.index ["call_sign"], name: "index_agencies_on_call_sign", unique: true
    t.index ["stripe_id"], name: "index_agencies_on_stripe_id", unique: true
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
    t.index ["confirmation_token"], name: "index_staffs_on_confirmation_token", unique: true
    t.index ["email"], name: "index_staffs_on_email", unique: true
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

end
