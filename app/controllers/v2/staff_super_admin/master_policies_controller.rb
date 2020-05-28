##
# V2 StaffAgency Master Policies Controller
# File: app/controllers/v2/staff_agency/master_policies_controller.rb

module V2
  module StaffSuperAdmin
    class MasterPoliciesController < StaffSuperAdminController

      def index
        @master_policies = Policy.where(policy_type_id: 2) || []
        if @master_policies.present?
          render json: @master_policies, status: :ok
        else
          render json: { message: 'No master policies' }
        end
      end
      
      def show
        @policy = Policy.where(policy_type_id: 2).find(params[:id])
        @master_policy_coverages = @policy.policy_coverages || []
        @buildings = @policy.insurables.buildings || []
        @communities = @policy.insurables.communities || []
        if @master_policy_coverages.present?
          render json: { @master_policy_coverages, @buildings, @communities }, status: :ok
        else
          render json: { message: 'Policy does\'t exist' }
        end
      end
    end
  end # module StaffAgency
end
