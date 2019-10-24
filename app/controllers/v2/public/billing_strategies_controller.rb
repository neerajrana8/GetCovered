##
# V2 Public BillingStrategies Controller
# File: app/controllers/v2/public/billing_strategies_controller.rb

module V2
  module Public
    class BillingStrategiesController < PublicController
            
      def index
        if params[:short]
          super(:@billing_strategies, @substrate)
        else
          super(:@billing_strategies, @substrate)
        end
      end
      
      
      private
      
        def view_path
          super + "/billing_strategies"
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
