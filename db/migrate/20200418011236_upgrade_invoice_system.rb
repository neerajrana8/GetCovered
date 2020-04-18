class UpgradeInvoiceSystem < ActiveRecord::Migration[5.2]
  def up
    # add proration_reduction to Invoice
    add_column :invoices, :proration_reduction, :integer, null: false, default: 0
    
    # restore defaults to policy billing dispute fields
    change_column_default :policies, :billing_dispute_count, 0
    change_column_default :policies, :billing_dispute_status, 0
    
    # add line items
    add_column :line_items, :refundability, :integer, null: false
    PolicyQuote.each do |pq|
      # add line items
      with_deposit = pq.invoices.sort{|a,b| a.due_date <=> b.due_date }.first
      with_deposit.line_items.create!(
        title: "Deposit Fees",
        price: pq.policy_premium.deposit_fees,
        refundability: 'no_refund'
      )
      with_deposit.line_items.create!(
        title: "Amortized Fees",
        price: with_deposit.total - with_deposit.subtotal - pq.policy_premium.deposit_fees,
        refundability: 'no_refund'
      )
      with_deposit.line_items.create!(
        title: "Premium Payment",
        price: with_deposit.subtotal,
        refundability: 'prorated_refund'
      )
      without_deposits = pq.invoices.select{|inv| inv != with_deposit }
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
    Invoices.each do |inv|
      # subtotal used to be total - fees; now it is total - proration_reduction, which is 0
      inv.update_columns(subtotal: total, proration_reduction: 0)
    end
  end
  
  
  def down
    Invoices.each do |inv|
      # restore subtotal to total - fees instead of total - proration_reduction
      inv.update_columns(subtotal: inv.line_items.where(refundability: 'prorated_refund').inject(0){|sum,li| sum + li.price })
    end
    
    remove_column :invoices, :proration_reduction
    remove_column :line_items, :refundability
  end
end
