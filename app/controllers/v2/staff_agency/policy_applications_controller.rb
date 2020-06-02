##
# V2 StaffAgency PolicyApplications Controller
# File: app/controllers/v2/staff_agency/policy_applications_controller.rb

module V2
  module StaffAgency
    class PolicyApplicationsController < StaffAgencyController
      
      before_action :set_policy_application, only: [:show]
      
      before_action :set_substrate, only: [:index]
      
      def index
        if current_staff.organizable_id == Agency::GET_COVERED_ID
          super(:@policy_applications, PolicyApplication.all)
        else
          super(:@policy_applications, PolicyApplication.where(agency_id: current_staff.organizable_id))
        end
      end
      
      def show; end
      
      private
      
      def view_path
        super + "/policy_applications"
      end

      def set_policy_application
        @policy_application =
          if current_staff.organizable_id == Agency::GET_COVERED_ID
            PolicyApplication.find(params[:id])
          else
            access_model(::PolicyApplication, params[:id])
          end
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
  end
end
