##
# V2 StaffAgency Claims Controller
# File: app/controllers/v2/staff_agency/claims_controller.rb

module V2
  module StaffSuperAdmin
    class ClaimsController < StaffSuperAdminController
      
      before_action :set_claim,
        only: %i[show]
      
      def index
        super(:@claims, Claim.all)
      end
      
      def show; end
      
      private
      
      def view_path
        super + '/claims'
      end
        
      def set_claim
        @claim = Claim.find(params[:id])
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
