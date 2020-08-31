class AddExternalToInvoices < ActiveRecord::Migration[5.2]
  def change
    add_column :invoices, :external, :boolean, null: false, default: false
  end
end
