class UpgradeLineItems < ActiveRecord::Migration[5.2]
  def change
    # MOOSE WARNING need to add values for these boiz since they are null false!
    add_reference :line_items, :policy_premium_item, index: true, null: false
    
    add_column :line_items, :original_total_due, null: false # set to price
    add_column :line_items, :total_due, null: false           # set to price - proration_reduction
    add_column :line_items, :total_received, null: false # set to collected
    add_column :line_items, :total_processed, null: false # set to 0
    
  end
end

#    t.string "title"
#    t.integer "price", default: 0
#    t.bigint "invoice_id"
#    t.datetime "created_at", null: false
#    t.datetime "updated_at", null: false
#    t.integer "refundability", null: false
#    t.integer "category", default: 0, null: false
#    t.boolean "priced_in", default: false, null: false
#    t.integer "collected", default: 0, null: false
#    t.integer "proration_reduction", default: 0, null: false
#    t.date "full_refund_before_date"
#    t.index ["invoice_id"], name: "index_line_items_on_invoice_id"
