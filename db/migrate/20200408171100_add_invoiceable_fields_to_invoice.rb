class AddInvoiceableFieldsToInvoice < ActiveRecord::Migration[5.2]

  def up
    add_reference(:invoices, :invoiceable_quote, polymorphic: true)
    add_reference(:invoices, :invoiceable_product, polymorphic: true)
    Invoice.each do |inv|
      inv.update_columns(
        invoiceable_quote_type: inv.policy_quote_id.nil? ? nil : 'PolicyQuote',
        invoiceable_quote_id: inv.policy_quote_id,
        invoiceable_product_type: inv.policy_id.nil? ? nil : 'Policy',
        invoiceable_product_id: inv.policy_id
      )
    end
    remove_reference(:invoices, :policy_quote)
    remove_reference(:invoices, :policy)
  end
  
  def down
    # WARNING: if any policies have a non-Policy inv. product or a non-PolicyQuote inv. quote, that information will be lost
    add_reference(:invoices, :policy_quote)
    add_reference(:invoices, :policy)
    Invoice.each do |inv|
      inv.update_columns(
        policy_id: inv.invoiceable_product_type == 'Policy' ? inv.invoiceable_product_id : nil,
        policy_quote_id: inv.invoiceable_quote_type == 'PolicyQuote' ? inv.invoiceable_quote_id : nil
      )
    end
    remove_reference(:invoices, :invoiceable_quote, polymorphic: true)
    remove_reference(:invoices, :invoiceable_product, polymorphic: true)
  end
end
