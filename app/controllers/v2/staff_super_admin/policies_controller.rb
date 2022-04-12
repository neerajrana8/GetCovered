##
# V2 StaffSuperAdmin Policies Controller
# File: app/controllers/v2/staff_super_admin/policies_controller.rb

module V2
  module StaffSuperAdmin
    class PoliciesController < StaffSuperAdminController
      include PoliciesMethods

      before_action :set_policy,
                    only: %i[update show refund_policy cancel_policy update_coverage_proof delete_policy_document
                             get_leads add_policy_documents]
      before_action :set_optional_coverages, only: [:show]

      before_action :set_substrate, only: [:index]

      def index
        super(:@policies, @substrate, :agency, :account, :primary_user, :policy_type)
      end

      def show; end

      def search
        @policies = Policy.search(params[:query]).records
        render json: @policies.to_json, status: 200
      end

      def get_leads
        @leads = [@policy.primary_user.lead]
        @site_visits = @leads.last.lead_events.order("DATE(created_at)").group("DATE(created_at)").count.keys.size
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

        if params[:insurable_id].present?
          insurable = Insurable.find(params[:insurable_id])
          insurable_units_ids =
            if InsurableType::UNITS_IDS.include?(insurable.insurable_type_id)
              insurable.id
            else
              [
                insurable.units&.pluck(:id),
                insurable.id,
                insurable.insurables.ids
              ].flatten.uniq.compact
            end

          @substrate = @substrate.joins(:insurables).where(insurables: { id: insurable_units_ids })
        end
      end
    end
  end
end
