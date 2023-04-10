module PolicyRenewal

  # Policy Renew completing service. called from ACORD file download script to finalize renewal process.
  # The Premium is updated using the latest set of rates from the current year.

  class RefreshRatesService < ApplicationService

    attr_accessor :policy, :community, :number_of_insured_users

    def initialize(policy_number)
      @policy = Policy.find_by_number(policy_number)
    end

    def call
      raise "Policy not found for POLICY_NUMBER=#{policy_number}." if policy.blank?
      raise "Parent community for insurable not found for POLICY_NUMBER=#{policy_number}." if community.blank?
      raise "Policy had no policy application." if policy.policy_application.blank?

      @community = @policy&.primary_insurable&.parent_community
      @number_of_insured_users = @policy.policy_users.count

      binding.pry
      renewal_date = policy.expiration_date + 1.day
      community.get_qbe_rates(number_of_insured_users, renewal_date)

      match_coverage_limits
    end

    private

    #When matching coverage limits it is important to match the coverage amount, coverage type and deductible.
    #TODO: dev example - how to update coverages? Policy id: 11922
    def match_coverage_limits
      policy.policy_coverages.each do |policy_coverage|
        upgrade_policy_coverage(policy_coverage) if need_to_upgrade?(policy_coverage)
      end
    end


    def need_to_upgrade?(policy_coverage)
      #TODO: when policy application nil? uploaded from pma or upload coverage proof page?
      billing_strategy = policy.policy_application.billing_strategy
      upd_rates = updated_rates(billing_strategy)

    end

    def upgrade_policy_coverage(policy_coverage)

    end

    def irc
      @irc ||= community.insurable_rate_configurations.last
    end

    def updated_coverage_options
      irc.configuration["coverage_options"]
    end

    def monthly_rates
      irc.rates['rates'][number_of_insured_users]['month']
    end

    def quarterly_rates
      irc.rates['rates'][number_of_insured_users]['quarter']
    end

    def bi_annual_rates
      irc.rates['rates'][number_of_insured_users]['bi_annual']
    end

    def annual_rates
      irc.rates['rates'][number_of_insured_users]['annual']
    end

    def updated_rates(billing_strategy)
      case billing_strategy.slug
        when 'month'     then monthly_rates
        when 'quarter'   then quarterly_rates
        when 'bi_annual' then bi_annual_rates
        when 'annual'    then annual_rates
        else
          raise "Unknown billing strategy for POLICY_NUMBER=#{policy_number}."
      end
    end



  end
end
