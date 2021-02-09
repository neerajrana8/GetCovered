##
# V2 StaffSuperAdmin Policies Controller
# File: app/controllers/v2/staff_super_admin/policies_controller.rb

module V2
  module StaffSuperAdmin
    class PoliciesController < StaffSuperAdminController
      include PoliciesMethods

      before_action :set_policy,
                    only: %i[update show refund_policy cancel_policy update_coverage_proof delete_policy_document get_leads]

      before_action :set_substrate, only: [:index]

      def index
        super(:@policies, @substrate)
      end

      def show; end

      def search
        @policies = Policy.search(params[:query]).records
        render json: @policies.to_json, status: 200
      end

      def get_leads
        @leads = [@policy.primary_user.lead]
        @site_visits=@leads.last.lead_events.order("DATE(created_at)").group("DATE(created_at)").count.keys.size
        render 'v2/shared/leads/index'
      end

      def get_policies
        user_ids = @tracking_url.leads.pluck(:user_id).compact
        policies_ids = PolicyUser.where(user_id: user_ids).pluck(:policy_id).compact
        @policies = Policy.where(id: policies_ids)
        render 'v2/staff_super_admin/policies/index'
      end

      private

      def view_path
        super + '/policies'
      end

      def set_policy
        @policy = access_model(::Policy, params[:id])
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Policy)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.policies
        end
      end
    end
  end
end
