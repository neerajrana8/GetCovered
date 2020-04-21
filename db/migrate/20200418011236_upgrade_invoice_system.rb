class UpgradeInvoiceSystem < ActiveRecord::Migration[5.2]
  def up
    # add proration_reduction to Invoice
    add_column :invoices, :proration_reduction, :integer, null: false, default: 0
    
    # restore defaults to policy billing dispute fields
    change_column_default :policies, :billing_dispute_count, 0
    change_column_default :policies, :billing_dispute_status, 0
    
    # add line items
    add_column :line_items, :refundability, :integer, null: false
    
    ::Invoice.group("invoiceable_type, invoiceable_id").pluck("invoiceable_type, invoiceable_id").each do |invoiceable|
      # get PolicyQuote
      policy_data = nil
      invoices = nil
      case invoiceable[0]
        when 'PolicyQuote'
          policy_data = { deposit_fees: ::PolicyQuote.find(invoiceable[1]).policy_premium.deposit_fees }
        when 'Policy'
          policy_data = { deposit_fees: ::Policy.find(invoiceable[1]).policy_quotes.accepted.take.policy_premium.deposit_fees }
      end
      if policy_data.nil?
        raise "Migration failed: invoiceable type '#{invoiceable[0]}' is unknown! Please modify the UpgradeInvoiceSystem migration's up method to add instructions for deriving policy information from this type."
      else
        invoices = ::Invoice.where(invoiceable_type: invoiceable[0], invoiceable_id: invoiceable[1])
      end
      # add line items
      with_deposit = invoices.sort{|a,b| a.due_date <=> b.due_date }.first
      with_deposit.line_items.create!(
        title: "Deposit Fees",
        price: policy_data[:deposit_fees],
        refundability: 'no_refund'
      )
      with_deposit.line_items.create!(
        title: "Amortized Fees",
        price: with_deposit.total - with_deposit.subtotal - policy_data[:deposit_fees],
        refundability: 'no_refund'
      )
      with_deposit.line_items.create!(
        title: "Premium Payment",
        price: with_deposit.subtotal,
        refundability: 'prorated_refund'
      )
      without_deposits = invoices.select{|inv| inv != with_deposit }
      without_deposits.each do |inv|
        inv.line_items.create!(
          title: "Amortized Fees",
          price: inv.total - inv.subtotal,
          refundability: 'no_refund'
        )
        inv.line_items.create!(
          title: "Premium Payment",
          price: inv.subtotal,
          refundability: 'prorated_refund'
        )
      end
    end
    ::Invoice.all.each do |inv|
      # subtotal used to be total - fees; now it is total - proration_reduction, which is 0
      inv.update_columns(subtotal: inv.total, proration_reduction: 0)
    end
  end
  
  
  def down
    ::Invoice.all.each do |inv|
      # restore subtotal to total - fees instead of total - proration_reduction
      inv.update_columns(subtotal: inv.line_items.where(refundability: 'prorated_refund').inject(0){|sum,li| sum + li.price })
    end
    ::LineItem.all.delete_all
    
    remove_column :invoices, :proration_reduction
    remove_column :line_items, :refundability
  end
end
