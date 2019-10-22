##
# V2 StaffSuperAdmin PolicyQuotes Controller
# File: app/controllers/v2/staff_super_admin/policy_quotes_controller.rb

module V2
  module StaffSuperAdmin
    class PolicyQuotesController < StaffSuperAdminController
      
      before_action :set_policy_quote,
        only: [:show]
            
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@policy_quotes)
        else
          super(:@policy_quotes)
        end
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/policy_quotes"
        end
        
        def set_policy_quote
          @policy_quote = access_model(::PolicyQuote, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::PolicyQuote)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.policy_quotes
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
  end # module StaffSuperAdmin
end
