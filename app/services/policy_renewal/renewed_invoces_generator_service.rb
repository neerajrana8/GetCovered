module PolicyRenewal

  # Policy Renew completing service. called from ACORD file download script to finalize renewal process

  class RenewedInvoicesGeneratorService < ApplicationService

    attr_accessor :policy

    def initialize(policy_number)
      @policy = Policy.find_by_number(policy_number)
    end

    def call
      raise "Policy not found for POLICY_NUMBER=#{policy_number}." if policy.blank?

      invoices_generation_status = false

      application = @policy.policy_application
      quote = application.qbe_estimate
      quote.update(policy_id: @policy.id) if quote.policy_id.blank?
      quote.qbe_build_coverages
      application.qbe_quote(quote.id)

      premium = PolicyPremium.create(policy_quote: quote, policy: @policy)
      policy_fee = (quote.carrier_payment_data['policy_fee'] || 0)
      premium.fees.create(title: "Policy Fee", type: 'ORIGINATION', amount_type: 'FLAT', amount: policy_fee, enabled: true, ownerable_type: "Carrier", ownerable_id: ::QbeService.carrier_id, hidden: true) unless policy_fee == 0

      unless premium.id
        invoices_generation_status = false
        return "Failed to create premium! #{premium.errors.to_h}"
      else
        strategy = premium.billing_strategy
        payment_plan = strategy.renewal.nil? ? strategy.new_business["payments"] : strategy.renewal["payments"]
        result = premium.initialize_all(quote.est_premium - quote.carrier_payment_data["policy_fee"] + (premium.total_tax < 0 ? premium.total_tax : 0),
                                        start_date: @policy.expiration_date + 1.day,
                                        last_date: @policy.expiration_date + 1.year,
                                        billing_strategy_terms: payment_plan,
                                        tax: (premium.total_tax <= 0 ? 0 : premium.total_tax),
                                        tax_recipient: quote.policy_application.carrier)
        unless result.nil?
          invoices_generation_status = false
          return "Failed to initialize premium! #{result}"
        else
          quote.generate_invoices_for_term(false, false)
          invoices_generation_status = true
        end
      end

      invoices_generation_status
    end

  end
end

