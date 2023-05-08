##
# V2 StaffSuperAdmin Policies Controller
# File: app/controllers/v2/staff_super_admin/policies_controller.rb

module V2
  module StaffSuperAdmin
    class PoliciesController < StaffSuperAdminController
      include PoliciesMethods
      include ActionController::Caching
      include ActionController::MimeResponds

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

      # /v2/staff_super_admin/policies/export.csv
      def export
        @policies = ::Policies::List.new(params, export: false).call
        policies_json = render_to_string(template: 'v2/policies/list', formats: [:json])
        policies = JSON.parse(policies_json).dig('data') || []
        respond_to do |format|
          format.csv { send_data generate_csv(policies), filename: "policies-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.csv" }
        end
      end

      def show
        # NOTE: show master_policy_configurations for policies which are covered by master policies
        @master_policy_configuration = @policy.master_policy_configuration if @policy.policy_type&.master_coverage
      end

      def search
        @policies = Policy.search(params[:query]).records
        render json: @policies.to_json, status: 200
      end

      # TODO: Old code related to leads, need refactoring
      def get_leads
        unless @policy.primary_user.lead.nil?
          @leads = [@policy.primary_user.lead]
          # @site_visits = @leads.last.lead_events.order("DATE(created_at)").group("DATE(created_at)").count.keys.size
          @site_visites = @leads.first.lead_events_cx
        end
        render 'v2/shared/leads/leads_by_policy'
      end

      def get_policies
        user_ids = @tracking_url.leads.pluck(:user_id).compact
        policies_ids = PolicyUser.where(user_id: user_ids).pluck(:policy_id).compact
        @policies = Policy.where(id: policies_ids)
        render 'v2/staff_super_admin/policies/index'
      end

      private

      def generate_csv(policies)
        require 'csv'
        CSV.generate(headers: true) do |csv|
          csv << ['Number', 'Status', 'T Code', 'Community', 'Building', 'Unit', 'PM Account', 'Agency', 'Effective_date',
                  'Expiration Date', 'Cutomer Name', 'Email', 'Product', 'Billing Strategy', 'Update Date', 'Policy Source']
          policies.each do |policy|
            csv << [policy.dig('number'), policy.dig('status'), 'T Code', policy.dig('primary_insurable', 'parent_community', 'title'),
                    policy.dig('primary_insurable', 'parent_building', 'title'), policy.dig('primary_insurable', 'title'),
                    policy.dig('account', 'title'), policy.dig('agency', 'title'), policy.dig('effective_date'),
                    policy.dig('expiration_date'), policy.dig('primary_user', 'full_name'), policy.dig('primary_user', 'email'),
                    policy.dig('policy_type_title'), policy.dig('billing_strategy'), policy.dig('updated_at'),
                    (policy.dig('policy_in_system') == true ? 'Internal' : 'External')]
          end
        end
      end

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
