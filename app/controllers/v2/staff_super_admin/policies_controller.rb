##
# V2 StaffSuperAdmin Policies Controller
# File: app/controllers/v2/staff_super_admin/policies_controller.rb

module V2
  module StaffSuperAdmin
    class PoliciesController < StaffSuperAdminController
      include PoliciesMethods
      include ActionController::Caching

      before_action :set_policy,
                    only: %i[update show refund_policy cancel_policy update_coverage_proof delete_policy_document
                             get_leads add_policy_documents]
      before_action :set_optional_coverages, only: [:show]

      def index
        filtering_keys = %i[policy_in_system agency_id status account_id policy_type_id number users]
        params_slice ||= []
        params_slice = params[:filter].slice(*filtering_keys) if params[:filter].present?
        @policies = Policy.filter(params_slice).includes(
                        :policy_application,
                        :agency,
                        :account,
                        :policy_type,
                        :policy_quotes,
                        :carrier,
                        :primary_user,
                        :policy_users,
                        :policy_insurables,
                        { users: :profile },
                        { agency: :billing_strategies },
                        { policy_quotes: :policy_application },
                        { policy_application: :billing_strategy }
                      ).references(:profiles, :agencies)
                      .preload(
                        :policy_type,
                        :carrier,
                        { insurables: :account },
                        :policy_quotes,
                        :policy_application,
                        :policy_users,
                        { agency: :billing_strategies },
                        { policy_quotes: { policy_application: :billing_strategy } },
                        { policy_application: :billing_strategy },
                        { primary_user: :profile }
                      )

        if params[:insurable_id].present?
          @policies = @policies.where(policy_insurables: { insurable_id: params[:insurable_id] })
        end

        total = @policies.count

        # TODO: Fix cause, - Pages from frontend starts counting from 0, page=1 better to be 1 not 0
        unless params[:pagination].present?
          params[:pagination] = {
            page: 0,
            per: 10
          }
        end

        params[:pagination][:page] += 1

        @policies = @policies.order(created_at: :desc).page(params[:pagination][:page]).per(params[:pagination][:per])

        # TODO: Deprecate unless client side support
        response.headers['total-pages'] = @policies.total_pages
        response.headers['current-page'] = @policies.current_page
        response.headers['total-entries'] = total
      end

      def show; end

      def search
        @policies = Policy.search(params[:query]).records
        render json: @policies.to_json, status: 200
      end

      def get_leads
        @leads = [@policy.primary_user.lead]
        @site_visits = @leads.last.lead_events.order("DATE(created_at)").group("DATE(created_at)").count.keys.size
        render 'v2/shared/leads/leads_by_policy'
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
