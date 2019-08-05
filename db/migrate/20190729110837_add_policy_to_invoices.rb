class AddPolicyToInvoices < ActiveRecord::Migration[5.2]
  def change
    add_reference :invoices, :policy, index: true
    add_column :policies, :policy_in_system, :boolean
    add_column :charges, :amount, :integer, default: 0
    add_column :policies, :auto_pay, :boolean
  end
end
