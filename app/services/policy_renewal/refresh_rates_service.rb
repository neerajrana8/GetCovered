module PolicyRenewal

  # Policy Renew completing service. called from ACORD file download script to finalize renewal process.
  # The Premium is updated using the latest set of rates from the current year.

  class RefreshRatesService < ApplicationService

    attr_accessor :policy, :community, :number_of_insured_users, :refresh_rates_status

    def initialize(policy_number)
      @policy = Policy.find_by_number(policy_number)
      @community = @policy&.primary_insurable&.parent_community
      @refresh_rates_status = true
    end

    def call
      raise "Policy not found for POLICY_NUMBER=#{policy_number}." if policy.blank?
      raise "Parent community for insurable not found for POLICY_NUMBER=#{policy_number}." if community.blank?
      #TEMPORARILY
      raise "Policy had no policy application." if policy.policy_application.blank?


      @number_of_insured_users = @policy.policy_users.count

      community.get_qbe_rates(number_of_insured_users, policy.renewal_date)

      match_coverage_limits

      #TBD: need to add log to which one left the same which one upgraded which not matched at all
      refresh_rates_status
    end

    private

    #When matching coverage limits it is important to match the coverage amount, coverage type and deductible.
    #TODO: dev example - how to update coverages? Policy id: 11922
    def match_coverage_limits
      policy.policy_coverages.each do |policy_coverage|
        puts policy_coverage.designation
        upgrade_policy_coverage(policy_coverage) if need_to_upgrade?(policy_coverage)
      end
    end


    def need_to_upgrade?(policy_coverage)
      billing_strategy = policy.policy_application.billing_strategy
      upd_rates = updated_rates(billing_strategy)
      current_limit = upd_rates.find{|el| el["schedule"] == policy_coverage.designation &&
                                          el["coverage_limits"][policy_coverage.designation] == policy_coverage.limit}
      current_limit.blank?
    end

    def upgrade_policy_coverage(policy_coverage)
      begin
      billing_strategy = policy.policy_application.billing_strategy
      #if not found need to match higher one from rates, or from coverage, or calculate at last step

      upd_rates = updated_rates(billing_strategy)

      higher_limit_coverage = upd_rates.find{|el| el["schedule"] == policy_coverage.designation &&
        el["coverage_limits"][policy_coverage.designation] > policy_coverage.limit}
      higher_limit = higher_limit_coverage["coverage_limits"]&.values&.last if higher_limit_coverage.present?

      if higher_limit.blank?
        matched_coverage = updated_coverage_options.find{|el| el.first == policy_coverage.designation}
        higher_limit_coverage = matched_coverage.last["options"].find{|el| el["value"] >= policy_coverage.limit } if matched_coverage.present?
        higher_limit = higher_limit_coverage["coverage_limits"]&.values&.last if higher_limit_coverage.present?
      end

      if higher_limit.blank?
        # Calculated after quote build with quote.qbe_build_coverages
        # calculate on next step on qbe_build_coverages
        # if can't calculate disable coverage on enable flag?
      else
        policy_coverage.update(limit: higher_limit)
      end
      rescue Exception => e
        return if policy_coverage.designation.in(['all_peril','loss_of_use','theft','wind_hail'])
        refresh_rates_status = false
        #Added for debug for now will move to logger
        message = "Unable to update rates for policy id: #{ policy.id }\n\n policy coverage id: #{ policy_coverage.id }"
        message += "#{ e.to_json }\n\n"
        message += e.backtrace.join("\n")
        from = Rails.env == "production" ? "no-reply-#{ Rails.env.gsub('_','-') }@getcovered.io" : 'no-reply@getcovered.io'
        ActionMailer::Base.mail(from: from,
                                to: 'hannabts@nitka.com',
                                subject: "[Get Covered] Renewal Refresh rates error",
                                body: message).deliver_now()
      end

    end

    def irc
      @irc ||= @community.insurable_rate_configurations.last
    end

    def updated_coverage_options
      irc.configuration["coverage_options"]
    end

    def monthly_rates
      irc.rates['rates'][@number_of_insured_users]['month']
    end

    def quarterly_rates
      irc.rates['rates'][@number_of_insured_users]['quarter']
    end

    def bi_annual_rates
      irc.rates['rates'][@number_of_insured_users]['bi_annual']
    end

    def annual_rates
      irc.rates['rates'][@number_of_insured_users]['annual']
    end

    def updated_rates(billing_strategy)
      case billing_strategy.slug
      when 'monthly'     then monthly_rates
      when 'quarterly'   then quarterly_rates
      when 'bi_annually' then bi_annual_rates
      when 'annually'    then annual_rates
      else
        raise "Unknown billing strategy for POLICY_NUMBER=#{policy.policy_number}."
      end
    end



  end
end
