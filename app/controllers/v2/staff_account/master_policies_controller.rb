##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffAccount
    class MasterPoliciesController < StaffAccountController
      
      def index
        @master_policies = current_staff.organizable.policies.where(policy_type_id: 2) || []
        if @master_policies.present?
          render json: @master_policies, status: :ok
        else
          render json: { message: 'No master policies' }
        end
      end
      
      def show
        @master_policy = current_staff.organizable.policies.where(policy_type_id: 2).find(params[:id])
        if @master_policy.present?
          render json: @master_policy, status: :ok
        else
          render json: { message: 'Policy does\'t exist' }
        end
      end
    end
  end # module StaffAccount
end
