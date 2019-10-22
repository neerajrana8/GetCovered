##
# V2 StaffAccount LeaseTypes Controller
# File: app/controllers/v2/staff_account/lease_types_controller.rb

module V2
  module StaffAccount
    class LeaseTypesController < StaffAccountController
            
      def index
        if params[:short]
          super(:@lease_types)
        else
          super(:@lease_types)
        end
      end
      
      
      private
      
        def view_path
          super + "/lease_types"
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::LeaseType)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.lease_types
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
  end # module StaffAccount
end
