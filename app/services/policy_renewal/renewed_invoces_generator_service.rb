module PolicyRenewal

  # Policy Renew completing service. called from ACORD file download script to finalize renewal process

  class RenewedInvoicesGeneratorService < ApplicationService

    attr_accessor :policy

    def initialize(policy_number)
      @policy = Policy.find_by_number(policy_number)
    end

    def call
      raise "Policy not found for POLICY_NUMBER=#{policy_number}." if policy.blank?
      return "Policy with POLICY_NUMBER=#{policy_number} not valid for renewal." unless valid_for_renewal?

      invoices_generation_status = false

      application = policy.policy_application
      quote = application.qbe_estimate
      application.qbe_quote(quote.id)

      invoices_generation_status
    end

    private

    def valid_for_renewal?
      #ensure that the status and billing status show the policy as being
      #in good standing
      # carrier_id: 1
      # policy_type_id: 1
      # policy_in_system: true
      # billing_status: 'current' or 'rescinded'
    end

  end
end
# frozen_string_literal: true

