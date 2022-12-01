module MasterPolicies
  class GenerateNextInvoice < ActiveInteraction::Base
    object :master_policy, class: Policy
    time :range_start, default: 1.month.ago
    time :range_end,   default: Time.zone.now

    def execute
      ppi = ::PolicyPremiumItem.create!(
        policy_premium: policy_premium,
        title: "Premium",
        category: "premium",
        rounding_error_distribution: "first_payment_simple",
        total_due: amount * coverages.count,
        proration_calculation: "no_proration",
        proration_refunds_allowed: false,
        commission_calculation: "group_by_transaction",
        commission_creation_delay_hours: 10,
        recipient: policy_premium.commission_strategy,
        collector: ::Agency.where(master_agency: true).take
      )
      pppt = ::PolicyPremiumPaymentTerm.create!(
        policy_premium: policy_premium,
        first_moment: range_start.beginning_of_day,
        last_moment: range_start.end_of_day,
        time_resolution: 'day',
        invoice_available_date_override: Time.current.to_date,
        invoice_due_date_override: Time.current.to_date - 1.day,
        default_weight: 1
      )
      ppipt = ::PolicyPremiumItemPaymentTerm.create!(
        policy_premium_item: ppi,
        policy_premium_payment_term: pppt,
        weight: 1
      )
      invoice = ::Invoice.create!(
        available_date: Time.current.to_date,
        due_date: Time.current.to_date + 1.day,
        external: false,
        status: 'available',
        invoiceable: master_policy,
        payer: master_policy.account,
        collector: ppi.collector,
        line_items: coverages.map do |cov|
          ::LineItem.new(
            chargeable: ppipt,
            title: cov.number,
            original_total_due: amount,
            total_due: amount,
            preproration_total_due: amount,
            analytics_category: "master_policy_premium",
            policy_quote: nil,
            policy: master_policy
          )
        end
      )
      return invoice
    end

    private

    def coverages
      @coverages ||=
        master_policy.policies.where(coverages_condition).where(range_start: range_start, range_end: range_end)
    end

    def coverages_condition
      <<-SQL
        (effective_date >= :range_start AND expiration_date < :range_end) 
        OR (expiration_date > :range_start AND expiration_date < :range_end) 
        OR (effective_date >= :range_start AND effective_date < :range_end)
        OR (effective_date < :range_start AND expiration_date >= :range_end)
      SQL
    end

    def amount
      @amount ||= policy_premium.policy_premium_items.where(commission_calculation: 'no_payments').take.total_due
    end
    
    def policy_premium
      @policy_premium ||= master_policy.policy_premiums.take
    end
  end
end
