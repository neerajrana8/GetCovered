class AddInvoiceableFieldsToInvoice < ActiveRecord::Migration[5.2]

  def up
    if column_exists?(:invoices, :invoiceable_quote_id)
      # we've upgraded and downgraded & are upgrading again
      Invoice.all.each do |inv|
        inv.update_columns(
          invoiceable_quote_type: inv.policy_quote_id.nil? ? inv.invoiceable_quote_type : 'PolicyQuote',
          invoiceable_quote_id: inv.policy_quote_id || inv.invoiceable_quote_id,
          invoiceable_product_type: inv.policy_id.nil? ? inv.invoiceable_product_type : 'Policy',
          invoiceable_product_id: inv.policy_id || inv.invoiceable_product_id
        )
      end
      remove_reference(:invoices, :policy_quote, index: true)
      remove_reference(:invoices, :policy, index: true)
    else
      # migrate regularly
      add_reference(:invoices, :invoiceable_quote, polymorphic: true, index: { name: 'index_invoices_on_invoiceable_quote' })
      add_reference(:invoices, :invoiceable_product, polymorphic: true, index: { name: 'index_invoices_on_invoiceable_product' })
      Invoice.all.each do |inv|
        inv.update_columns(
          invoiceable_quote_type: inv.policy_quote_id.nil? ? nil : 'PolicyQuote',
          invoiceable_quote_id: inv.policy_quote_id,
          invoiceable_product_type: inv.policy_id.nil? ? nil : 'Policy',
          invoiceable_product_id: inv.policy_id
        )
      end
      remove_reference(:invoices, :policy_quote, index: true)
      remove_reference(:invoices, :policy, index: true)
    end
  end
  
  def down
    add_reference(:invoices, :policy_quote)
    add_reference(:invoices, :policy)
    found_irreversible_invoice = false
    Invoice.all.each do |inv|
      if (!inv.invoiceable_product_type.blank? && inv.invoiceable_product_type != 'Policy') || (!inv.invoiceable_quote_type.blank? && inv.invoiceable_quote_type != 'PolicyQuote')
        found_irreversible_invoice = true
        #raise ActiveRecord::IrreversibleMigration # do NOT do this anymore; we've made the column removals conditional & made up more complex instead
      end
      inv.update_columns(
        policy_id: inv.invoiceable_product_type == 'Policy' ? inv.invoiceable_product_id : nil,
        policy_quote_id: inv.invoiceable_quote_type == 'PolicyQuote' ? inv.invoiceable_quote_id : nil
      )
    end
    puts "At least one Invoice had a non-Policy invoiceable_product_type or a non-PolicyQuote invoiceable_quote_type. These columns have been retained" if found_irreversible_invoice
    unless found_irreversible_invoice
      remove_reference(:invoices, :invoiceable_quote, polymorphic: true, index: true)
      remove_reference(:invoices, :invoiceable_product, polymorphic: true, index: true)
    end
  end
end
