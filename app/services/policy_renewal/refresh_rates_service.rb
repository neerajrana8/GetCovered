module PolicyRenewal

  # Policy Renew completing service. called from ACORD file download script to finalize renewal process

  class RefreshRatesService < ApplicationService

    attr_accessor :policy_number
    attr_accessor :policy

    def initialize(policy_number)
      @policy_number = policy_number
      @policy = Policy.find_by_number(@policy_number)
    end

    def call
      raise "Policy not found for POLICY_NUMBER=#{policy_number}." if policy.blank?
      return "Policy with POLICY_NUMBER=#{policy_number} not valid for renewal." unless valid_for_renewal?


    end

    private

    def valid_for_renewal?
      #ensure that the status and billing status show the policy as being
      #in good standing
    end

  end
end
