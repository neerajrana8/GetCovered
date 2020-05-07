class EnsureInvoiceableTermsExist < ActiveRecord::Migration[5.2]
  def up
    # move invoices back to PolicyQuotes
    ::Invoice.where(invoiceable_type: "Policy").each do |inv|
      invy = inv.invoiceable.policy_quotes.accepted.take
      inv.update_columns(invoiceable_type: "PolicyQuote", invoiceable_id: invy.id)
    end
    ::Invoice.where(invoiceable_type: "PolicyGroup").each do |inv|
      invy = PolicyGroupQuote.where(policy_group_id: inv.invoiceable_id).accepted.take
      inv.update_columns(invoiceable_type: "PolicyGroupQuote", invoiceable_id: invy.id) if invy
    end
    # assign term_first_date and term_last_date to invoices missing them
    to_fix = ::Invoice.where(term_first_date: nil).or(::Invoice.where(term_last_date: nil)).where(invoiceable_type: "PolicyQuote")
                      .group("invoiceable_id").pluck("invoiceable_id")
    ::PolicyQuote.references("policy_applications" => "billing_strategies").includes("policy_application" => "billing_strategy")
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
          term_last_date: i+1 == start_dates.length ? pq.policy_application.expiration_date : start_dates[i+1] - 1.day
        )
      end
    end
  end
end
