##
# V2 User Policies Controller
# File: app/controllers/v2/user/policies_controller.rb

module V2
  module User
    class PoliciesController < UserController
      
      before_action :set_policy,
        only: [:show]
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@policies, @substrate)
        else
          super(:@policies, @substrate)
        end
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/policies"
        end
        
        def set_policy
          @policy = access_model(::Policy, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Policy)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.policies
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
  end # module User
end
