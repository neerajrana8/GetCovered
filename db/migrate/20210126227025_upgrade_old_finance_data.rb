class UpgradeOldFinanceData < ActiveRecord::Migration[5.2]
  def up
    dictionary = {}
    # Policy Premia
    ArchivedPolicyPremium.all.each do |old|
      pq = old.policy_quote
      pa = pq.policy_application
      # create PolicyPremium
      total_premium = old.base + (old.include_special_premium ? old.special_premium : 0)
      total_tax = old.taxes
      total_fee = old.total_fees
      prorated = !pq.policy.nil? && pq.policy.status == 'CANCELLED'
      premium = {
        policy_quote_id: pq_id,
        billing_strategy_id: old.billing_strategy_id,
        policy_id: old.policy_id,
        commission_strategy_id: pa.carrier_agency_authorization.commission_strategy_id,
        created_at: old.created_at,
        updated_at: old.updated_at,
        total_premium: total_premium,
        total_tax: total_tax,
        total_fee: total_fee,
        total: total_premium + total_tax + total_fee,
        prorated: prorated,
        prorated_term_first_moment: !prorated ? nil : pq.policy.effective_date.beginning_of_day,
        prorated_term_last_moment: !prorated ? nil : pq.policy.cancellation_date.end_of_day,
        force_no_refunds: false,
        error_info: nil
      }
      premium = PolicyPremium.create!(premium)
      # create PolicyPremiumPaymentTerms
      invoices = pq.invoices.order(term_first_date: :asc).to_a
      pppts = invoices.map do |inv|
        ::PolicyPremiumPaymentTerm.create!(
          policy_premium: premium,
          first_moment: inv.term_first_date.beginning_of_day,
          last_moment: inv.term_last_date.end_of_day,
          time_resolution: 'day',
          default_weight: 1,
          term_group: nil
        )
      end
      # create PolicyPremiumItems and PolicyPremiumItemPaymentTerms
      case pa.carrier_id
        when 1
        when 2
        when 3
        when 4
        when 5
        when 6
        else
          # MOOSE WARNING: some nils exist, don't they??? is that from missing policy_applications >____>???
      end
      
      
    end
    
  end
end
