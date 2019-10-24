##
# V2 StaffAgency Carriers Controller
# File: app/controllers/v2/staff_agency/carriers_controller.rb

module V2
  module StaffAgency
    class CarriersController < StaffAgencyController
      
      before_action :set_carrier,
        only: [:show]
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@carriers, @substrate)
        else
          super(:@carriers, @substrate)
        end
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/carriers"
        end
        
        def set_carrier
          @carrier = access_model(::Carrier, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Carrier)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.carriers
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
  end # module StaffAgency
end
