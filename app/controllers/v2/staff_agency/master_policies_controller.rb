##
# V2 StaffAgency Master Policies Controller
# File: app/controllers/v2/staff_agency/master_policies_controller.rb

module V2
  module StaffAgency
    class MasterPoliciesController < StaffAgencyController
      before_action :set_policy,
                    only: %i[update show communities add_insurable covered_units
                             cover_unit available_top_insurables available_units historically_coverage_units
                             cancel cancel_coverage master_policy_coverages cancel_insurable]

      def index
        master_policies_relation = Policy.where(policy_type_id: PolicyType::MASTER_ID, agency_id: @agency.id)
        if params[:account_id].present?
          master_policies_relation = master_policies_relation.where(account_id: params[:account_id])
        end
        @master_policies = paginator(master_policies_relation)
        render template: 'v2/shared/master_policies/index', status: :ok
      end

      def show
        render template: 'v2/shared/master_policies/show', status: :ok
      end

      def create
        carrier = Carrier.find(params[:carrier_id])
        account = Account.where(agency_id: carrier.agencies.ids).find(params[:account_id])

        @master_policy = Policy.new(create_params.merge(agency: account.agency,
                                                        carrier: carrier,
                                                        account: account,
                                                        policy_type_id: PolicyType::MASTER_ID,
                                                        status: 'BOUND'))
        @policy_premium = PolicyPremium.new(create_policy_premium)
        if @master_policy.errors.none? && @policy_premium.errors.none? && @master_policy.save && @policy_premium.save
          @master_policy.policy_premiums << @policy_premium
          render json: { message: 'Master Policy and Policy Premium created', payload: { policy: @master_policy.attributes } },
                 status: :created
        else
          render json: standard_error(
                         :master_policy_creation_error,
                         'Master policy was not created',
                         @master_policy.errors.merge!(@policy_premium.errors)
                       ),
                 status: :unprocessable_entity
        end
      end

      def update
        if @master_policy.policies.any?
          render json: standard_error(
                         :master_policy_update_error,
                         'Master policy has created policies',
                         @master_policy.errors.merge!(@policy_premium.errors)
                       ),
                 status: :unprocessable_entity
        else
          if @master_policy.update(update_params)
            render json: { message: 'Master Policy updated', payload: { policy: @master_policy.attributes } },
                   status: :created
          else
            render json: standard_error(
                           :master_policy_update_error,
                           'Master policy was not updated',
                           @master_policy.errors
                         ),
                   status: :unprocessable_entity
          end
        end
      end

      def communities
        insurables_relation = @master_policy.insurables
        @insurables = paginator(insurables_relation)
        render template: 'v2/shared/master_policies/insurables', status: :ok
      end

      def add_insurable
        insurable =
          @master_policy.
            account.
            insurables.
            where(insurable_type_id: InsurableType::COMMUNITIES_IDS | InsurableType::BUILDINGS_IDS).
            find_by(id: params[:insurable_id])

        if insurable.present?
          @master_policy.insurables << insurable

          insurable.buildings.each do |building|
            @master_policy.insurables << building
          end

          @master_policy.start_automatic_master_coverage_policy_issue
          render json: { message: 'Community added' }, status: :ok
        else
          render json: { error: :insurable_was_not_found, message: "Account doesn't have this insurable" },
                 status: :not_found
        end
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

      def covered_units
        insurables_relation =
          Insurable.
            joins(:policies).
            where(policies: { policy: @master_policy }, insurables: { insurable_type: InsurableType::UNITS_IDS })

        @insurables = paginator(insurables_relation)
        render template: 'v2/shared/master_policies/insurables', status: :ok
      end

      def cover_unit
        unit = Insurable.find(params[:insurable_id])
        if unit.policies.current.empty? && unit.leases&.count&.zero?
          last_policy_number = @master_policy.policies.maximum('number')
          policy = unit.policies.create(
            agency: @master_policy.agency,
            carrier: @master_policy.carrier,
            account: @master_policy.account,
            policy_coverages: @master_policy.policy_coverages,
            number: last_policy_number.nil? ? "#{@master_policy.number}_1" : last_policy_number.next,
            policy_type_id: PolicyType::MASTER_COVERAGE_ID,
            policy: @master_policy,
            status: 'BOUND',
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

      def master_policy_coverages
        @master_policy_coverages = paginator(@master_policy.policies.master_policy_coverages.current)
        render template: 'v2/shared/master_policies/master_policy_coverages', status: :ok
      end

      def historically_coverage_units
        @master_policy_coverages = paginator(@master_policy.policies.master_policy_coverages.not_active)
        render template: 'v2/shared/master_policies/master_policy_coverages', status: :ok
      end

      def cancel
        MasterCoverageCancelJob.perform_later(@master_policy.id)
        render json: { message: "Master policy #{@master_policy.number} was successfully cancelled"}
      end

      def cancel_insurable
        @insurable = @master_policy.insurables.find(params[:insurable_id])
        @master_policy.policies.master_policy_coverages.
          joins(:policy_insurables).
          where(policy_insurables: { insurable_id: @insurable.units.pluck(:id) }) do |policy|
          policy.update(status: 'CANCELLED', cancellation_date_date: Time.zone.now, expiration_date: Time.zone.now)
        end
        @master_policy.policy_insurables.where(insurable: @insurable).destroy_all
        render json: { message: "Master Policy Coverages for #{@insurable.title} cancelled" }, status: :ok
      end

      def cancel_coverage
        @master_policy_coverage =
          @master_policy.policies.master_policy_coverages.find(params[:master_policy_coverage_id])

        @master_policy_coverage.update(status: 'CANCELLED', cancellation_date_date: Time.zone.now, expiration_date: Time.zone.now)

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
        @master_policy = Policy.find_by(policy_type_id: PolicyType::MASTER_ID, id: params[:id], agency: @agency)
        render(json: { master_policy: 'not found' }, status: :not_found) if @master_policy.blank?
      end

      def create_params
        return({}) if params[:policy].blank?

        permitted_params = params.require(:policy).permit(
          :account_id, :agency_id, :auto_renew, :carrier_id, :effective_date,
          :expiration_date, :number,
          policy_coverages_attributes: %i[policy_application_id limit deductible enabled designation]
        )

        permitted_params
      end

      def update_params
        return({}) if params[:policy].blank?

        permitted_params = params.require(:policy).permit(
          :account_id, :agency_id, :auto_renew, :carrier_id, :effective_date,
          :expiration_date, :number,
          policy_coverages_attributes: %i[id policy_application_id policy_id
                                          limit deductible enabled designation]
        )

        existed_ids = permitted_params[:policy_coverages_attributes]&.map { |policy_coverage| policy_coverage[:id] }

        unless existed_ids.nil?
          (@master_policy.policy_coverages.pluck(:id) - existed_ids).each do |id|
            permitted_params[:policy_coverages_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end

        permitted_params
      end

      def create_policy_premium
        return({}) if params.blank?

        params.permit(:base, :total, :calculation_base, :carrier_base)
      end
    end
  end
end
