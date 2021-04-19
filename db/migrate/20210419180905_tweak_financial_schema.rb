class TweakFinancialSchema < ActiveRecord::Migration[5.2]
  def change
    # give invoices status_changed column
    add_column :invoices, :status_changed, :datetime, null: true
    ::Invoice.all.each do |inv|
      archinv = inv.archived_invoice_id.nil? ? nil : ::ArchivedInvoice.where(id: inv.archived_invoice_id).take
      inv.update_columns(status_changed: archinv&.status_changed || inv.updated_at)
    end
    change_column_null :invoices, :status_changed, false
  end
end
