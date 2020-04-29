class UpgradeInvoiceSystemForPremiumTracking < ActiveRecord::Migration[5.2]
  def change
    # add tracking columns to LineItem
    add_column :line_items, :collected, :integer, null: false, default: 0
    add_column :line_items, :proration_reduction, :integer, null: false, default: 0
    # add per-line-item logging to Refund
    add_column :refunds, :by_line_item, :jsonb
    ::Refund.all.each{|r| r.send(set_line_item_refunds); r.save }
    change_column_null :refunds, :by_line_item, false
    # add diagnostic error fields to Charge just in case an invoice update ever fails
    add_column :charges, :invoice_update_failed, :boolean, null: false, default: false
    add_column :charges, :invoice_update_error_call, :string, null: true
    add_column :charges, :invoice_update_error_record, :string, null: true
    add_column :charges, :invoice_update_error_hash, :jsonb, null: true
  end
end
# MOOSE WARNING: 
# set priced in
