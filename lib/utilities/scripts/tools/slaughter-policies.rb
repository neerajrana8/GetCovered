

def slaughter_policy(pr, be_merciful: false, no_repeat: [])
  condemned = []
  return condemned if no_repeat && no_repeat.include?(pr)
  if pr.class == ::Policy
    condemned.push(pr.policy_group)
    condemned += pr.policy_premiums.to_a
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
      condemned += slaughter_policy(pq.policy_application, be_merciful: true, no_repeat: no_repeat + [pr])
      condemned += pq.policy_application&.policy_users.to_a
      condemned += pq.policy_application&.policy_insurables.to_a
      condemned.push(pq.policy_application&.policy_application_group)
    end
    condemned += pr.policy_coverages.to_a
    condemned += pr.policy_users.to_a
    condemned += pr.policy_insurables.to_a
    condemned.push(pr)
  elsif pr.class == ::PolicyApplication
    condemned += pr.policy_coverages.to_a
    condemned.push(pr.policy_application_group)
    pr.policy_quotes.each do |pq|
      condemned.push(pq.policy_premium)
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
      condemned += pr.policy_users.to_a
      condemned.push(pq)
      if pq.policy
        condemned += slaughter_policy(pq.policy_application, be_merciful: true, no_repeat: no_repeat + [pr])
      end
    end
    condemned.push(pr)
  elsif pr.class == ::PolicyQuote
    npr = pr.policy_application || pr.policy
    if npr
      condemned = slaughter_policy(npr, be_merciful: true)
    else
      condemned.push(pr)
      condemned.push(pr.policy_premium)
      condemned.push(pr.policy_group_quote)
      condemned.push(pr.policy_group_quote&.policy_group_premium)
      (pr.invoices.to_a + pr.policy_group_quote&.invoices.to_a).each do |i|
        condemned += i.line_items.to_a
        condemned += i.charges.to_a
        condemned += i.refunds.to_a
        condemned.push(i)
      end
    end
  end
  condemned = condemned.compact
  condemned = condemned.uniq
  return condemned if be_merciful
  condemned.each{|c| c.delete }
end



def kill_dem_problemz(really_kill: false)
  begin
    ActiveRecord::Base.transaction do
      # kill policy quotes without policies or policy applications
      ::PolicyQuote.all.select{|pq| pq.policy.nil? && pq.policy_application.nil? }.each do |pq|
        if really_kill
          slaughter_policy(pq)
        else
          condemned = slaughter_policy(pq, be_merciful: true)
          unless condemned.blank?
            puts "!!!!!! first slaughter found records"
            condemned.each{|c| puts "#{c.class.name} #{c.id}" }
            puts "!!!!!! first slaughter found records"
            exit
          end
        end
      end
      # kill policies & policy quotes without invoices, or with invoices without payers
      ::Policy.where.not(policy_type_id: ::PolicyType::MASTER_COVERAGE_ID).select{|p| p.invoices.blank? || p.invoices.any?{|i| i.payer.nil? } }.each do |p|
        if really_kill
          slaughter_policy(p)
        else
          condemned = slaughter_policy(p, be_merciful: true)
          unless condemned.blank?
            puts "!!!!!! second slaughter found records"
            condemned.each{|c| puts "#{c.class.name} #{c.id}" }
            puts "!!!!!! second slaughter found records"
            exit
          end
        end
      end
      ::PolicyQuote.where(id: (1000...2000)).where.not(status: ['estimated', 'quote_failed']).select{|pq| pq.invoices.blank? || pq.invoices.any?{|i| i.payer.nil? } }.each do |pq|
        if really_kill
          slaughter_policy(pq)
        else
          condemned = slaughter_policy(pq, be_merciful: true)
          unless condemned.blank?
            puts "!!!!!! third slaughter found records"
            condemned.each{|c| puts "#{c.class.name} #{c.id}" }
            puts "!!!!!! third slaughter found records"
            exit
          end
        end
      end
      # kill PolicyGroups and Deposit Choice policies
      ::PolicyApplication.where.not(policy_application_group_id: nil).or(::PolicyApplication.where(carrier_id: 6)).each do |pa|
        if really_kill
          slaughter_policy(pa)
        else
          condemned = slaughter_policy(pa, be_merciful: true)
          unless condemned.blank?
            puts "!!!!!! fourth slaughter found records"
            condemned.each{|c| puts "#{c.class.name} #{c.id}" }
            puts "!!!!!! fourth slaughter found records"
            exit
          end
        end
      end
      # kill fees & taxes (no policy with these things exists on production so woomba schnoomba)
      ::PolicyPremium.where("amortized_fees > 0").or(::PolicyPremium.where("deposit_fees > 0")).or(::PolicyPremium.where("taxes > 0")).where.not(policy_quote_id: nil).all.each do |premium|
        next if [5,6].include?(premium.policy_quote&.policy_application&.carrier_id || premium.policy&.carrier_id)
        if !really_kill
          puts "!!!!! tax and fee cull found record"
          puts "PolicyPremium #{premium.id}"
          puts "!!!!! tax and fee cull found record"
          exit
        end
        #premium.calculation_base = premium.internal_base + premium.internal_special_premium + premium.internal_taxes + premium.amortized_fees
        premium.base = premium.base + premium.amortized_fees + premium.deposit_fees + premium.taxes
        #premium.total_fees = premium.total_fees - premium.amortized_fees - premium.deposit_fees
        premium.amortized_fees = 0
        premium.deposit_fees = 0
        premium.taxes = 0
        premium.calculate_total
        premium.save!
        (premium.policy_quote&.invoices || premium.policy&.invoices || []).each do |invoice|
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
  rescue ActiveRecord::RecordInvalid => e
    puts "HELL HATH COME"
    puts "Record: #{e.record.class.name} ##{e.record.id}"
    puts "Errors: #{e.record.errors.to_h}"
    puts "Backtrace: #{e.backtrace.join("\n")}"
  end
end
