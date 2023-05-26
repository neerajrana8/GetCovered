module Qbe
  module Finance
    # Qbe::Finance::GenerateInvoicesForTerm
    class GenerateInvoicesForTerm < ApplicationService

      attr_accessor :policy
      attr_accessor :term

      def initialize(policy, term)
        @policy = policy
        @term = term
      end

      def call
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
            quote.generate_invoices_for_term(true, false)
            invoices_generation_status = true
          end
        end

        invoices_generation_status
      end

    end
  end
end