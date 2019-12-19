##
# V2 StaffSuperAdmin PolicyApplications Controller
# File: app/controllers/v2/staff_super_admin/policy_applications_controller.rb

module V2
  module StaffSuperAdmin
    class PolicyApplicationsController < StaffSuperAdminController
      
      before_action :set_policy_application, only: [:show]
            
      def index
        super(:@policy_applications, PolicyApplication)
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/policy_applications"
        end
        
        def set_policy_application
          @policy_application = PolicyApplication.find(params[:id])
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
