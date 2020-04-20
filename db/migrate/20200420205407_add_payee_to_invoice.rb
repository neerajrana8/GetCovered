class AddPayeeToInvoice < ActiveRecord::Migration[5.2]
  def up
    if column_exists?(:invoices, :payee_id)
      # we've upgraded and downgraded & are upgrading again
      Invoice.all.each do |inv|
        inv.update_columns(
          payee_type: inv.user_id.nil? ? inv.payee_type : 'User',
          payee_id: inv.user_id.nil? ? inv.payee_id : inv.user_id
        )
      end
      remove_reference(:invoices, :user, index: true)
    else
      # migrate regularly
      add_reference(:invoices, :payee, polymorphic: true, index: { name: 'index_invoices_on_payee' })
      Invoice.all.each do |inv|
        inv.update_columns(
          payee_type: inv.user_id.nil? ? nil : 'User',
          payee_id: inv.user_id.nil? ? nil : inv.user_id
        )
      end
      remove_reference(:invoices, :user, index: true)
    end
  end
  
  def down
    add_reference(:invoices, :user)
    found_irreversible_invoice = false
    Invoice.all.each do |inv|
      if(!inv.payee_type.nil? && inv.payee_type != 'User')
        found_irreversible_invoice = true
      end
      inv.update_columns(
        user_id: inv.payee_type == 'User' ? inv.payee_id : nil
      )
    end
    puts "At least one Invoice had a payee_type other than User. The payee_type & payee_id columns have been retained." if found_irreversible_invoice
    unless found_irreversible_invoice
      remove_reference(:invoices, :payee, polymorphic: true, index: true)
    end
  end
end
