##
# V2 StaffAgency Commissions Controller
# File: app/controllers/v2/staff_agency/commissions_controller.rb

module V2
  module StaffAgency
    class CommissionsController < StaffAgencyController
      
      before_action :set_commission,
        only: [:show]
            
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@commissions)
        else
          super(:@commissions)
        end
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/commissions"
        end
        
        def set_commission
          @commission = access_model(::Commission, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Commission)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.commissions
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
