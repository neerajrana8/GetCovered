##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffSuperAdmin
    class MasterPoliciesController < StaffSuperAdminController
      before_action :set_policy, only: %i[show communities available_units covered_units available_top_insurables
                                          historically_coverage_units master_policy_coverages]

      def index
        master_policies_relation = Policy.where(policy_type_id: PolicyType::MASTER_ID)
        master_policies_relation = master_policies_relation.where(status: params[:status]) if params[:status].present?
        @master_policies = paginator(master_policies_relation)
        render template: 'v2/shared/master_policies/index', status: :ok
      end

      def show
        render template: 'v2/shared/master_policies/show', status: :ok
      end

      def communities
        insurables_relation = @master_policy.insurables
        @insurables = paginator(insurables_relation)
        render template: 'v2/shared/master_policies/insurables', status: :ok
      end

      def covered_units
        insurables_relation =
          Insurable.
            joins(:policies).
            where(policies: { policy: @master_policy }, insurables: { insurable_type: InsurableType::UNITS_IDS }).
            distinct

        @insurables = paginator(insurables_relation)
        render template: 'v2/shared/master_policies/insurables', status: :ok
      end

      def available_top_insurables
        insurables_type =
          if %w[communities buildings].include?(params[:insurables_type])
            params[:insurables_type].to_sym
          else
            :communities_and_buildings
          end
        insurables_relation =
          @master_policy.
            account.
            insurables.
            send(insurables_type).
            where.not(id: @master_policy.insurables.communities_and_buildings.ids)
        @insurables = paginator(insurables_relation)
        render template: 'v2/shared/master_policies/insurables', status: :ok
      end

      def available_units
        insurables_relation = ::MasterPolicies::AvailableUnitsQuery.call(@master_policy)
        @insurables = paginator(insurables_relation)
        render template: 'v2/shared/master_policies/insurables', status: :ok
      end

      def historically_coverage_units
        @master_policy_coverages = paginator(@master_policy.policies.master_policy_coverages.not_active)
        render template: 'v2/shared/master_policies/master_policy_coverages', status: :ok
      end

      def master_policy_coverages
        @master_policy_coverages = paginator(@master_policy.policies.master_policy_coverages.current)
        render template: 'v2/shared/master_policies/master_policy_coverages', status: :ok
      end

      private

      def set_policy
        @master_policy = Policy.find_by(policy_type_id: PolicyType::MASTER_ID, id: params[:id])
        render(json: { error: :not_found, message: 'Master policy not found' }, status: :not_found) if @master_policy.blank?
      end
    end
  end
end
