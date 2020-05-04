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
    # move invoices back to PolicyQuotes
    ::Invoice.where(invoiceable_type: "Policy").each do |inv|
      invy = inv.invoiceable.policy_quotes.accepted.take
      inv.update_columns(invoiceable_type: "PolicyQuote", invoiceable_id: invy.id)
    end
    ::Invoice.where(invoiceable_type: "PolicyGroup").each do |inv|
      invy = PolicyGroupQuote.where(policy_group_id: inv.invoiceable_id).accepted.take
      inv.update_columns(invoiceable_type: "PolicyGroupQuote", invoiceable_id: invy.id)
    end
    # assign term_first_date and term_last_date to invoices missing them
    to_fix = ::Invoice.where(term_first_date: nil).or(::Invoice.where(term_last_date: nil)).where(invoiceable_type: "PolicyQuote")
                      .group("invoiceable_id").pluck("invoiceable_id")
    ::PolicyQuote.references("invoices", "policy_applications" => "billing_strategies").includes("invoices", "policy_application" => "billing_strategy")
                 .where(id: to_fix).each do |pq|
      sorted_invoices = pq.invoices.sort{|a,b| a.due_date <=> b.due_date }
      start_dates = pq.policy_application.billing_strategy.new_business['payments'].map.with_index do |p,i|
        p == 0 ? nil : pq.policy_application.effective_date + i.months
      end.compact
      if start_dates.length != sorted_invoices.length
        throw "Migration failed; policy quote ##{pq.id} has ##{sorted_invoices.length} invoices but ##{start_dates.length} billing periods"
      end
      sorted_invoices.each.with_index do |inv, i|
        inv.update!(
          term_first_date: start_dates[i],
          term_last_date: i+1 == start_dates.length ? pq.policy_application.expiration_date - 1.day : start_dates[i+1] - 1.day
        )
      end
    end
    # fix LineItem settings
    ::LineItem.update_all(priced_in: true)
    ::Invoice.where("proration_reduction > 0").each do |inv|
      dist = inv.get_fund_distribution(inv.proration_reduction, :adjustment, leave_line_item_models: true)
      dist.each do |li|
        li['line_item'].update!(proration_reduction: li['amount'])
      end
    end
    ::Invoice.where(status: 'complete').each do |inv|
      dist = inv.get_fund_distribution(inv.total, :payment, leave_line_item_models: true)
      dist.each do |li|
        li['line_item'].update!(collected: li['amount'])
      end
    end
    ::Invoice.where("amount_refunded > 0").each do |inv|
      dist = inv.get_fund_distribution(inv.total, :refund, leave_line_item_models: true)
      dist.each do |li|
        li['line_item'].update!(collected: li['line_item'].collected - li['amount'])
      end
    end
    # run unearned premium updates
    ::PolicyPremium.all.each do |pp|
      pp.update_unearned_premium
    end
  end
  
  def down
    # move invoices from PolicyQuotes
    ::Invoice.where(invoiceable_type: "PolicyQuote").where.not(status: 'quoted').each do |inv|
      inv.update!(invoiceable: inv.invoiceable.policy)
    end
    ::Invoice.where(invoiceable_type: "PolicyGroupQuote").where.not(status: 'quoted').each do |inv|
      inv.update!(invoiceable: inv.invoiceable.policy_group)
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
