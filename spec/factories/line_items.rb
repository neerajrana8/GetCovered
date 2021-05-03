FactoryBot.define do
  factory :line_item do
    title {|n| "Line Item #{n}" }
    priced_in { false }
    original_total_due { 10000 }
    total_due { 10000 }
    total_reducing { 0 }
    total_received { 0 }
    preproration_total_due { 10000 }
    duplicatable_reduction_total { 0 }
   # chargeable###############
  end
end

=begin
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
=end
