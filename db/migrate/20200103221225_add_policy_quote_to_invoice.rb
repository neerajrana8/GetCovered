class AddPolicyQuoteToInvoice < ActiveRecord::Migration[5.2]
  def change
    add_reference :invoices, :policy_quote
  end
end
