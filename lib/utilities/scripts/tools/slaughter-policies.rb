

def slaughter_policy_or_application(pr)
  condemned = []
  if pr.class == ::Policy
    condemned.push(pq.policy_group)
    pr.policy_quotes.each do |pq|
      (pq.invoices.to_a + pq.policy_group_quote&.invoices.to_a).each do |i|
        condemned += i.line_items.to_a
        condemned += i.charges.to_a
        condemned += i.refunds.to_a
        condemned.push(i)
      end
      condemned.push(pq.policy_group_quote)
      condemned.push(pq.policy_group_quote&.policy_group_premium)
      condemned.push(pq.policy_premium)
      condemned.push(pq)
      condemned.push(pq.policy_application)
      condemned += pq.policy_application&.policy_users.to_a
      condemned += pq.policy_application&.policy_insurables.to_a
      condemned.push(pq.policy_application&.policy_application_group)
    end
    condemned += pr.policy_coverages.to_a
    condemned += pr.policy_users.to_a
    condemned += pr.policy_insurables.to_a
    condemned.push(pr)
  elsif pr.class == ::PolicyApplication
    condemned.push(pr.policy_application_group)
    pr.policy_quotes.each do |pq|
      condemned.push(pq.policy_group_quote)
      condemned.push(pq.policy_group_quote&.policy_group_premium)
      condemned += pr.policy_users.to_a
      condemned += pr.policy_insurables.to_a
      (pq.invoices.to_a + pq.policy_group_quote&.invoices.to_a).each do |i|
        condemned += i.line_items.to_a
        condemned += i.charges.to_a
        condemned += i.refunds.to_a
        condemned.push(i)
      end
      condemned += pq.policy_users.to_a
      condemned.push(pq)
      if pq.policy
        condemned.push(pq.policy.policy_group)
        condemned += pq.policy.policy_coverages.to_a
        condemned += pq.policy.policy_users.to_a
        condemned += pq.policy.policy_insurables.to_a
        condemned.push(pq.policy)
      end
    end
    condemned.push(pr)
  end
  condemned = condemned.compact
  condemned = condemned.uniq
  condemned.each{|c| c.delete }
end



def kill_dem_problemz
  ActiveRecord::Base.transaction do
    # kill PolicyGroups and Deposit Choice policies
    ::PolicyApplication.where.not(policy_application_group_id: nil).or(::PolicyApplication.where(carrier_id: 6)).each do |pa|
      slaughter_policy_or_application(pa)
    end
    # kill fees & taxes (no policy with these things exists on production so woomba schnoomba)
    ::PolicyPremium.where("amortized_fees > 0").or(::PolicyPremium.where("deposit_fees > 0")).or(::PolicyPremium.where("taxes > 0")).where.not(policy_quote_id: nil).all.each do |premium|
      next if [5,6].include?(premium.policy_quote.policy_application.carrier_id)
      premium.update!(amortized_fees: 0, deposit_fees: 0, taxes: 0, base: premium.base + premium.amortized_fees + premium.deposit_fees + premium.taxes, total_fees: premium.total_fees - premium.amortized_fees - premium.deposit_fees, total: premium.total - premium.amortized_fees - premium.deposit_fees - premium.taxes)
      premium.policy_quote.invoices.each do |invoice|
        extra_price = 0
        extra_collected = 0
        extra_proration_reduction = 0
        invoice.line_items.where(category: ['amortized_fees', 'deposit_fees', 'taxes']).to_a.each do |doomed_boi|
          extra_price += doomed_boi.price
          extra_collected += doomed_boi.collected
          extra_proration_reduction = doomed_boi.proration_reduction
          doomed_boi.delete
        end
        inheritor = invoice.line_items.find{|li| li.category == 'base_premium' }
        inheritor.update!(price: inheritor.price + extra_price, collected: inheritor.collected + extra_collected, proration_reduction: inheritor.proration_reduction + extra_proration_reduction)
      end
    end
  end
end
