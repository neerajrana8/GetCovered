module MasterPoliciesMethods
  extend ActiveSupport::Concern

  included do
    before_action :set_policy,
                  only: %i[update show communities add_insurable covered_units
                           cover_unit available_top_insurables available_units historically_coverage_units
                           cancel cancel_coverage master_policy_coverages cancel_insurable auto_assign_all
                           auto_assign_insurable]

    def show
      render template: 'v2/shared/master_policies/show', status: :ok
    end

    def create
      carrier = Carrier.find(params[:carrier_id])
      account = Account.where(agency_id: carrier.agencies.ids).find(params[:account_id])
      error = nil
      ::ActiveRecord::Base.transaction do
        begin
          @master_policy = Policy.create!(create_params.merge(agency: account.agency,
                                                    carrier: carrier,
                                                    account: account,
                                                    status: 'BOUND'))
          @policy_premium = PolicyPremium.create!(policy: @master_policy)
          @ppi = ::PolicyPremiumItem.create!(
            policy_premium: @policy_premium,
            title: "Per-Coverage Premium",
            category: "premium",
            rounding_error_distribution: "first_payment_simple",
            total_due: create_policy_premium[:base],
            proration_calculation: "no_proration",
            proration_refunds_allowed: false,
            commission_calculation: "no_payments",
            recipient: @policy_premium.commission_strategy,
            collector: ::Agency.where(master_agency: true).take
          )
          @policy_premium.update_totals(persist: false)
          @policy_premium.save!
        rescue ActiveRecord::RecordInvalid => err
          error = err
          raise ActiveRecord::Rollback
        end
      end
      
      if error.nil?
        render json: { message: 'Master Policy and Policy Premium created', payload: { policy: @master_policy.attributes } },
               status: :created
      else
        render json: standard_error(
                       :master_policy_creation_error,
                       'Master policy was not created',
                       error.record.errors
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
        error = nil
        ::ActiveRecord::Base.transaction do
          begin
            @master_policy.update!(update_params)
            if create_policy_premium && create_policy_premium[:base] && create_policy_premium[:base] != @master_policy.policy_premiums.take.total_premium
              premium = @master_policy.policy_premiums.take
              ppi = premium.policy_premium_items.where(commission_calculation: 'no_payments').take
              ppi.update!(original_total_due: create_policy_premium[:base], total_due: create_policy_premium[:base])
              @master_policy.premium.update_totals(persist: false)
              @master_policy.premium.save!
            end
          rescue ActiveRecord::RecordInvalid => err
            error = err
            raise ActiveRecord::Rollback
          end
        end
        if error.nil?
          render json: { message: 'Master Policy updated', payload: { policy: @master_policy.attributes } },
                 status: :created
        else
          render json: standard_error(
                         :master_policy_update_error,
                         'Master policy was not updated',
                         error.record.errors
                       ),
                 status: :unprocessable_entity
        end
      end
    end

    def communities
      insurables_relation = @master_policy.insurables.distinct
      @insurables = paginator(insurables_relation)
      render template: 'v2/shared/master_policies/insurables', status: :ok
    end

    def auto_assign_all
      @master_policy.policy_insurables.update(auto_assign: params[:auto_assign_value])
      @insurables = paginator(@master_policy.insurables.distinct)
      render template: 'v2/shared/master_policies/insurables', status: :ok
    end

    def auto_assign_insurable
      policy_insurable = @master_policy.policy_insurables.where(insurable_id: params[:insurable_id]).take

      if policy_insurable.present?
        policy_insurable.update(auto_assign: !policy_insurable.auto_assign)
        @insurables = paginator(@master_policy.insurables.distinct)
        render template: 'v2/shared/master_policies/insurables', status: :ok
      else
        render json: { error: :insurable_was_not_found, message: 'Insurable is not assigned to the master policy' },
               status: :not_found
      end
    end

    def add_insurable
      insurable =
        @master_policy.
          account.
          insurables.
          where(insurable_type_id: InsurableType::COMMUNITIES_IDS | InsurableType::BUILDINGS_IDS).
          find_by(id: params[:insurable_id])

      if insurable.present?
        if @master_policy.insurables.where(id: params[:insurable_id]).any?
          render json: { error: :insurable_already_added, message: 'Insurable already added' },
                 status: :bad_request
        else
          @master_policy.insurables << insurable

          insurable.buildings.each do |building|
            @master_policy.insurables << building
          end

          # NOTE: Disable master policy coverage issueing
          # @master_policy.start_automatic_master_coverage_policy_issue

          unless params[:auto_assign].nil?
            @master_policy.
              policy_insurables.
              where(insurable: [insurable, *insurable.buildings]).
              update(auto_assign: params[:auto_assign])
          end

          response_json =
            if ::MasterPolicies::AvailableUnitsQuery.call(@master_policy, insurable.id).any?
              { message: 'Community added', allow_edit: false }
            else
              { message: 'Community added', allow_edit: true }
            end
          render json: response_json, status: :ok
        end
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

      insurables_relation = ::MasterPolicies::AvailableTopInsurablesQuery.call(@master_policy, insurables_type)
      @insurables = insurables_relation.all
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
          where(policies: { policy: @master_policy }, insurables: { insurable_type: InsurableType::UNITS_IDS }).
          distinct

      @insurables = paginator(insurables_relation)
      render template: 'v2/shared/master_policies/insurables', status: :ok
    end

    def cover_unit
      unit = Insurable.find(params[:insurable_id])
      if unit.policies.where(policy_type_id: PolicyType::MASTER_MUTUALLY_EXCLUSIVE[@master_policy.policy_type_id]).current.empty? && unit.occupied?
        policy_number = MasterPolicies::GenerateNextCoverageNumber.run!(master_policy_number: @master_policy.number)
        policy = unit.policies.create(
          agency: @master_policy.agency,
          carrier: @master_policy.carrier,
          account: @master_policy.account,
          policy_coverages_attributes: @master_policy.policy_coverages.map do |policy_coverage|
            policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
          end,
          number: policy_number,
          policy_type: @master_policy.policy_type.coverage,
          policy: @master_policy,
          status: 'BOUND',
          system_data: @master_policy.system_data,
          effective_date: @master_policy.effective_date,
          expiration_date: @master_policy.expiration_date
        )
        if policy.errors.blank?
          unit.update(covered: true)
          render json: policy.to_json, status: :ok
        else
          response = { error: :policy_creation_problem, message: 'Policy was not created', payload: policy.errors }
          render json: response.to_json, status: :internal_server_error
        end
      else
        render json: { error: :bad_unit, message: 'Unit does not fulfil the requirements' }.to_json, status: :bad_request
      end
    end

    def cover_unit_with_configuration
      unit = Insurable.find(params[:insurable_id])
      mpc = @master_policy.find_closest_master_policy_configuration(unit)

      if mpc.nil?
        render json: { error: :invalid_master_policy_configuration }, status: 400
      end

      effective_date = @master_policy.effective_date
      effective_date = mpc.program_start_date unless mpc.program_start_date.nil?

      if params[:start_date].present?
        effective_date = params[:start_date]
      end

      if unit.policies.where(policy_type_id: PolicyType::MASTER_MUTUALLY_EXCLUSIVE[@master_policy.policy_type_id]).current.empty? && unit.occupied?
        policy_number = MasterPolicies::GenerateNextCoverageNumber.run!(master_policy_number: @master_policy.number)
        policy = unit.policies.create(
          agency: @master_policy.agency,
          carrier: @master_policy.carrier,
          account: @master_policy.account,
          policy_coverages_attributes: @master_policy.policy_coverages.map do |policy_coverage|
            policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
          end,
          number: policy_number,
          policy_type: @master_policy.policy_type.coverage,
          policy: @master_policy,
          status: 'BOUND',
          system_data: @master_policy.system_data,
          effective_date: effective_date, # @master_policy.effective_date,
          expiration_date: @master_policy.expiration_date
        )
        if policy.errors.blank?
          unit.update(covered: true)
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
      render json: { message: "Master policy #{@master_policy.number} was successfully cancelled" }
    end

    def cancel_insurable
      @insurable = @master_policy.insurables.find(params[:insurable_id])
      new_expiration_date =
        @master_policy.effective_date > Time.zone.now ? @master_policy.effective_date : Time.zone.now
      @master_policy.policies.master_policy_coverages.
        joins(:policy_insurables).
        where(policy_insurables: { insurable_id: @insurable.units_relation&.pluck(:id) }).each do |policy|
        policy.update(status: 'CANCELLED', cancellation_date: Time.zone.now, expiration_date: new_expiration_date)
        policy.primary_insurable&.update(covered: false)
      end
      @master_policy.policy_insurables.where(insurable: @insurable).destroy_all
      @master_policy.policy_insurables.where(insurable: @insurable.buildings).destroy_all
      render json: { message: "Master Policy Coverages for #{@insurable.title} cancelled" }, status: :ok
    end

    def cancel_coverage
      @master_policy_coverage =
        @master_policy.policies.master_policy_coverages.find(params[:master_policy_coverage_id])

      new_expiration_date =
        @master_policy_coverage.effective_date > Time.zone.now ? @master_policy_coverage.effective_date : Time.zone.now

      @master_policy_coverage.update(status: 'CANCELLED', cancellation_date: Time.zone.now, expiration_date: new_expiration_date)

      if @master_policy_coverage.errors.any?
        render json: {
                       error: :server_error,
                       message: 'Master policy coverage was not cancelled',
                       payload: @master_policy_coverage.errors.full_messages
                     }.to_json,
               status: :bad_request
      else
        @master_policy_coverage.primary_insurable&.update(covered: false)
        render json: { message: "Master policy coverage #{@master_policy_coverage.number} was successfully cancelled" }
      end
    end

    private

    def create_params
      return({}) if params[:policy].blank?

      permitted_params = params.require(:policy).permit(
        :account_id, :agency_id, :auto_renew, :carrier_id, :effective_date, :policy_type_id,
        :expiration_date, :number, system_data: [:landlord_sumplimental],
        policy_coverages_attributes: %i[policy_application_id title limit deductible enabled designation]
      )

      permitted_params
    end

    def update_params
      return({}) if params[:policy].blank?

      permitted_params = params.require(:policy).permit(
        :account_id, :agency_id, :auto_renew, :carrier_id, :effective_date,
        :expiration_date, :number, system_data: [:landlord_sumplimental],
        policy_coverages_attributes: %i[id policy_application_id policy_id title
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
      params.permit(:base)
      # old params, for reference: params.permit(:base, :total, :calculation_base, :carrier_base)
    end

    def supported_filters(called_from_orders = false)
      @calling_supported_orders = called_from_orders
      {
        id: %i[scalar array],
        carrier: {
          id: %i[scalar array],
          title: %i[scalar like]
        },
        number: %i[scalar like],
        policy_type_id: %i[scalar array],
        status: %i[scalar like array],
        created_at: %i[scalar like],
        updated_at: %i[scalar like],
        policy_in_system: %i[scalar like],
        effective_date: %i[scalar like],
        expiration_date: %i[scalar like],
        agency_id: %i[scalar array],
        account_id: %i[scalar array]
      }
    end
  end
end
