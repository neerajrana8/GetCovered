##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffSuperAdmin
    class MasterPoliciesController < StaffSuperAdminController
      include MasterPoliciesMethods

      def index
        master_policies_relation = Policy.where(policy_type_id: PolicyType::MASTER_ID).order(created_at: :desc)
        master_policies_relation = master_policies_relation.where(status: params[:status]) if params[:status].present?
        @master_policies = paginator(master_policies_relation)
        render template: 'v2/shared/master_policies/index', status: :ok
      end

      def set_policy
        @master_policy = Policy.find_by(policy_type_id: PolicyType::MASTER_ID, id: params[:id])
        render(json: { error: :not_found, message: 'Master policy not found' }, status: :not_found) if @master_policy.blank?
      end
    end
  end
end
