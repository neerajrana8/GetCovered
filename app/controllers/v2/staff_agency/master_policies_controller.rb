##
# V2 StaffAgency Master Policies Controller
# File: app/controllers/v2/staff_agency/master_policies_controller.rb

module V2
  module StaffAgency
    class MasterPoliciesController < StaffAgencyController
      include MasterPoliciesMethods

      check_privileges 'policies.master'


      def index
        master_policies_relation = Policy.where(policy_type_id: PolicyType.master.ids, agency_id: @agency.id).order(created_at: :desc)
        master_policies_relation = master_policies_relation.where(account_id: params[:account_id]) if params[:account_id].present?
        master_policies_relation = master_policies_relation.where(status: params[:status]) if params[:status].present?

        super(:@master_policies, master_policies_relation)
        render template: 'v2/shared/master_policies/index', status: :ok
      end

      def set_policy
        @master_policy = Policy.find_by(policy_type_id: PolicyType.master.ids, id: params[:id], agency: @agency)
        render(json: { master_policy: 'not found' }, status: :not_found) if @master_policy.blank?
      end

    end
  end
end
