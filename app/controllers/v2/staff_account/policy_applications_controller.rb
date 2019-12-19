##
# V2 StaffAccount PolicyApplications Controller
# File: app/controllers/v2/staff_account/policy_applications_controller.rb

module V2
  module StaffAccount
    class PolicyApplicationsController < StaffAccountController
      
      before_action :set_policy_application, only: [:show]
      
      before_action :set_substrate, only: [:index]
      
      def index
        super(:@policy_applications, @substrate)
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/policy_applications"
        end
        
        def set_policy_application
          @policy_application = access_model(::PolicyApplication, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::PolicyApplication)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.policy_applications
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
