##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffAccount
    class MasterPoliciesController < StaffAccountController
      before_action :set_policy, only: %i[show communities available_units covered_units historically_coverage_units
                                          master_policy_coverages cover_unit cancel_coverage available_top_insurables]

      def index
        master_policies_relation = Policy.where(policy_type_id: PolicyType::MASTER_ID, account: @account)
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
            where(policies: { policy: @master_policy }, insurables: { insurable_type: InsurableType::UNITS_IDS })

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
        insurables_relation = ::MasterPolicies::AvailableUnitsQuery.call(@master_policy, params[:insurable_id])
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

      def cover_unit
        unit = Insurable.find(params[:insurable_id])
        if unit.policies.empty? && unit.leases&.count&.zero?
          last_policy_number = @master_policy.policies.maximum('number')
          policy = unit.policies.create(
            agency: @master_policy.agency,
            carrier: @master_policy.carrier,
            account: @master_policy.account,
            policy_coverages: @master_policy.policy_coverages,
            number: last_policy_number.nil? ? "#{@master_policy.number}_1" : last_policy_number.next,
            policy_type_id: PolicyType::MASTER_COVERAGE_ID,
            status: 'BOUND',
            policy: @master_policy,
            effective_date: @master_policy.effective_date,
            expiration_date: @master_policy.expiration_date
          )
          if policy.errors.blank?
            render json: policy.to_json, status: :ok
          else
            response = { error: :policy_creation_problem, message: 'Policy was not created', payload: policy.errors }
            render json: response.to_json, status: :internal_server_error
          end
        else
          render json: { error: :bad_unit, message: 'Unit does not fulfil the requirements' }.to_json, status: :bad_request
        end
      end

      def cancel_coverage
        @master_policy_coverage =
          @master_policy.policies.master_policy_coverages.find(params[:master_policy_coverage_id])

        @master_policy_coverage.update(status: 'CANCELLED', cancellation_date_date: Time.zone.now)

        if @master_policy_coverage.errors.any?
          render json: {
                         error: :server_error,
                         message: 'Master policy coverage was not cancelled',
                         payload: @master_policy_coverage.errors.full_messages
                       }.to_json,
                 status: :bad_request
        else
          render json: { message: "Master policy coverage #{@master_policy_coverage.number} was successfully cancelled" }
        end
      end

      private

      def set_policy
        @master_policy = Policy.find_by(policy_type_id: PolicyType::MASTER_ID, id: params[:id], account: @account)
        render(json: { error: :not_found, message: 'Master policy not found' }, status: :not_found) if @master_policy.blank?
      end
    end
  end
end
