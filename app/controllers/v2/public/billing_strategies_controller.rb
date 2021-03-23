##
# V2 Public BillingStrategies Controller
# File: app/controllers/v2/public/billing_strategies_controller.rb

module V2
  module Public
    class BillingStrategiesController < PublicController
      
      def index
        policy_type = params[:policy_type].presence ? params[:policy_type] : 'residential'
        billing_strategy_policy_type = PolicyType.find_by_slug(policy_type)
        
        search_params = {
          agency_id: params[:agency_id].presence ? params[:agency_id].to_i : 1,
          carrier_id: params[:carrier_id].presence ? params[:carrier_id].to_i : nil
        }.compact
        @billing_strategies = billing_strategy_policy_type.billing_strategies.enabled.where(search_params)
      end
      
      private
      
      def view_path
        super + '/billing_strategies'
      end
        
      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::BillingStrategy)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.billing_strategies
        end
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def supported_orders
        supported_filters(true)
      end
        
    end
  end # module Public
end
