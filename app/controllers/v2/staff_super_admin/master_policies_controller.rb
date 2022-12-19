##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffSuperAdmin
    class MasterPoliciesController < StaffSuperAdminController
      include MasterPoliciesMethods

      def index
        master_policies_relation = Policy.where(policy_type_id: PolicyType::MASTER_IDS).order(created_at: :desc)
        master_policies_relation = master_policies_relation.where(status: params[:status]) if params[:status].present?

        master_policies_relation = master_policies_relation.where("number LIKE ?", "%#{params[:number]}%") if params[:number].present?
        master_policies_relation = master_policies_relation.where(account_id: params[:account_id]) if params[:account_id].present?

        if params[:insurable_id].present?
          insurable = Insurable.find(params[:insurable_id])

          current_types_ids = insurable.policies.current.pluck(:policy_type_id)
          master_policies_relation = master_policies_relation.where.not(policy_type_id: current_types_ids)
        end

        super(:@master_policies, master_policies_relation)
        render template: 'v2/shared/master_policies/index', status: :ok
      end

      def new
        @master_policy = Policy.new(
          effective_date: (Time.current + 1.months).at_beginning_of_month,
          policy_type_id: 2,
          carrier: Carrier.find(2)
        )
        @master_policy.qbe_master_build_coverage_options
        render @master_policy.as_json(include: :policy_coverages)
      end

      def set_policy
        @master_policy = Policy.find_by(policy_type_id: PolicyType::MASTER_IDS, id: params[:id])
        render(json: { error: :not_found, message: 'Master policy not found' }, status: :not_found) if @master_policy.blank?
      end
    end
  end
end
