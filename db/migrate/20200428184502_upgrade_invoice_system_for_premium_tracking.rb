class UpgradeInvoiceSystemForPremiumTracking < ActiveRecord::Migration[5.2]
  def up
    # add tracking columns to LineItem
    add_column :line_items, :collected, :integer, null: false, default: 0
    add_column :line_items, :proration_reduction, :integer, null: false, default: 0
    # add diagnostic error fields to Charge just in case an invoice update ever fails
    add_column :charges, :invoice_update_failed, :boolean, null: false, default: false
    add_column :charges, :invoice_update_error_call, :string, null: true
    add_column :charges, :invoice_update_error_record, :string, null: true
    add_column :charges, :invoice_update_error_hash, :jsonb, null: true
    # change payee to payer
    rename_column :invoices, :payee_id, :payer_id
    rename_column :invoices, :payee_type, :payer_type
    # fix LineItem settings
    ::LineItem.update_all(priced_in: true)
    ::Invoice.where("proration_reduction > 0").each do |inv|
      dist = inv.get_fund_distribution(inv.proration_reduction, :adjustment, leave_line_item_models: true)
      dist.each do |li|
        li['line_item'].update(proration_reduction: li['amount'])
      end
    end
    ::Invoice.where(status: 'complete').each do |inv|
      dist = inv.get_fund_distribution(inv.total, :payment, leave_line_item_models: true)
      dist.each do |li|
        li['line_item'].update(collected: li['amount'])
      end
    end
    ::Invoice.where("amount_refunded > 0").each do |inv|
      dist = inv.get_fund_distribution(inv.total, :refund, leave_line_item_models: true)
      dist.each do |li|
        li['line_item'].update(collected: li['line_item'].collected - li['amount'])
      end
    end
    # move invoices back to PolicyQuotes
    ::Invoice.where(invoiceable_type: "Policy").each do |inv|
      invy = inv.invoiceable.policy_quotes.accepted.take
      inv.update(invoiceable: invy)
    end
    ::Invoice.where(invoiceable_type: "PolicyGroup").each do |inv|
      invy = PolicyGroupQuote.where(policy_group_id: inv.invoiceable_id).accepted.take
      inv.update(invoiceable: invy)
    end
  end
  
  def down
    # move invoices from PolicyQuotes
    ::Invoice.where(invoiceable_type: "PolicyQuote").where.not(status: 'quoted').each do |inv|
      inv.update(invoiceable: inv.invoiceable.policy)
    end
    ::Invoice.where(invoiceable_type: "PolicyGroupQuote").where.not(status: 'quoted').each do |inv|
      inv.update(invoiceable: inv.invoiceable.policy_group)
    end
    # no need to fix line item settings, since the down migration just nukes the new fields
    # change payer back to payee
    rename_column :invoices, :payer_type, :payee_type
    rename_column :invoices, :payer_id, :payee_id
    # remove diagnostic error fields
    remove_column :charges, :invoice_update_error_hash
    remove_column :charges, :invoice_update_error_record
    remove_column :charges, :invoice_update_error_call
    remove_column :charges, :invoice_update_failed
    # remove tracking columns
    remove_column :line_items, :proration_reduction
    remove_column :line_items, :collected
  end
end
# MOOSE WARNING: 
# set priced in
