##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffAccount
    class MasterPoliciesController < StaffAccountController
      
#       def index
#         @master_policies = current_staff.organizable.policies.where(policy_type_id: 2) || []
#         if @master_policies.present?
#           render json: @master_policies, status: :ok
#         else
#           render json: { message: 'No master policies' }
#         end
#       end
#       
#       def show
#         @master_policy_covarages = current_staff.organizable.policies.where(policy_type_id: 3).find(params[:id])
#         if @master_policy_coverages.present?
#           render json: @master_policy_coverages, status: :ok
#         else
#           render json: { message: 'Policy does\'t exist' }
#         end
#       end

    end
  end # module StaffAccount
end
