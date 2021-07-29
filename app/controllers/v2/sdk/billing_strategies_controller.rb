##
# V2 Public BillingStrategies Controller
# File: app/controllers/v2/public/billing_strategies_controller.rb

module V2
  module Sdk
    class BillingStrategiesController < SdkController

      def index
        policy_type = params[:policy_type].presence ? params[:policy_type] : 'residential'
        billing_strategy_policy_type = PolicyType.find_by_slug(policy_type)

        @billing_strategies = @bearer.billing_strategies.where(policy_type: billing_strategy_policy_type, enabled: true)
      end

    end
  end
end
