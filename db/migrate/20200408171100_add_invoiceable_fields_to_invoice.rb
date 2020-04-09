class AddInvoiceableFieldsToInvoice < ActiveRecord::Migration[5.2]

  def up
    if column_exists?(:invoices, :invoiceable_id)
      # we've upgraded and downgraded & are upgrading again
      Invoice.all.each do |inv|
        inv.update_columns(
          invoiceable_type: inv.policy_id.nil? ? (inv.policy_quote_id.nil? ? inv.invoiceable_type : 'PolicyQuote') : 'Policy',
          invoiceable_id:   inv.policy_id.nil? ? (inv.policy_quote_id.nil? ? inv.invoiceable_id : inv.policy_quote_id) : inv.policy_id
        )
      end
      remove_reference(:invoices, :policy_quote, index: true)
      remove_reference(:invoices, :policy, index: true)
    else
      # migrate regularly
      add_reference(:invoices, :invoiceable, polymorphic: true, index: { name: 'index_invoices_on_invoiceable' })
      Invoice.all.each do |inv|
        inv.update_columns(
          invoiceable_type: inv.policy_id.nil? ? (inv.policy_quote_id.nil? ? nil : 'PolicyQuote') : 'Policy',
          invoiceable_id:   inv.policy_id.nil? ? (inv.policy_quote_id.nil? ? nil : inv.policy_quote_id) : inv.policy_id
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
      if(!inv.invoiceable_type.nil? && inv.invoiceable_type != 'Policy' && inv.invoiceable_type != 'PolicyQuote')
        found_irreversible_invoice = true
        #raise ActiveRecord::IrreversibleMigration # do NOT do this anymore; we've made the column removals conditional & made up more complex instead
      end
      # MOOSE WARNING: assumes policy_quotes.accepted is always of size 1...
      pqid = inv.invoiceable_type == 'Policy' && !inv.invoiceable_id.nil? ? inv.invoiceable.policy_quotes.accepted.take : nil
      pqid = pqid.id unless pqid.nil?
      inv.update_columns(
        policy_id: inv.invoiceable_type == 'Policy' ? inv.invoiceable_id : nil,
        policy_quote_id: inv.invoiceable_type == 'PolicyQuote' ? inv.invoiceable_id : inv.invoiceable_type == 'Policy' ? pqid : nil
      )
    end
    puts "At least one Invoice had an invoiceable_type other than Policy or PolicyQuote. The invoiceable_type column has been retained." if found_irreversible_invoice
    unless found_irreversible_invoice
      remove_reference(:invoices, :invoiceable, polymorphic: true, index: true)
    end
  end
end
