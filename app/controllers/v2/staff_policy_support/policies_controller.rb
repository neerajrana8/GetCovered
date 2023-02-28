##
# V2 StaffSuperAdmin Policies Controller
# File: app/controllers/v2/staff_super_admin/policies_controller.rb

module V2
  module StaffPolicySupport
    class PoliciesController < StaffPolicySupportController
      include PoliciesMethods

      before_action :set_policy,
                    only: %i[update show update_coverage_proof delete_policy_document]
      before_action :set_optional_coverages, only: [:show]

      before_action :set_substrate, only: [:index]

      def index
        super(:@policies, @substrate, :agency, :account, :primary_user)
      end

      # TODO: Needs refactoring
      def show
        if @policy.primary_insurable.nil?
          @min_liability = 1000000
          @max_liability = 30000000
        else
          insurable = @policy.primary_insurable.parent_community
          account = insurable&.account || @policy.account
          agency = account&.agency || insurable&.agency || @policy.agency
          carrier_id = agency&.providing_carrier_id(PolicyType::RESIDENTIAL_ID, insurable){|cid| (insurable.get_carrier_status(carrier_id) == :preferred) ? true : nil }
          carrier_policy_type = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take
          uid = (carrier_id == ::MsiService.carrier_id ? '1005' : carrier_id == ::QbeService.carrier_id ? 'liability' : nil)
          liability_options = (::InsurableRateConfiguration.get_inherited_irc(carrier_policy_type, account || agency, insurable, agency: agency)&.configuration['coverage_options']&.[](uid)&.[]('options') rescue  nil)
          if liability_options.nil?
            @min_liability = 1000000
            @max_liability = 30000000
          else
            @max_liability = liability_options&.map{|opt| opt['value'].to_i }&.max
            @min_liability = liability_options&.map{|opt| opt['value'].to_i }&.min
          end
        end

        if @min_liability.nil? || @min_liability == 0 || @min_liability == "null"
          @min_liability = 1000000
        end

        if @max_liability.nil? || @max_liability == 0 || @max_liability == "null"
          @max_liability = 30000000
        end

        @lease = @policy.latest_lease(lease_status: ['pending', 'current'])
        available_lease_date = @lease.nil? ? DateTime.current.to_date : @lease.sign_date.nil? ? @lease.start_date : @lease.sign_date
        @coverage_requirements = @policy.primary_insurable&.parent_community&.coverage_requirements_by_date(date: available_lease_date)

        # NOTE This is architectural flaw and bs way to get master policy
        begin
          master_policy = @policy.primary_insurable.parent_community.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
          @master_policy_configuration = MasterPolicy::ConfigurationFinder.call(master_policy, insurable, available_lease_date)
        rescue StandardError => e
          render json: {error: e}, status: 400
        end
      end

      def update
        if @policy.update(update_policy_attributes)

          # # TODO: Place to update policy status depended objects
          active_policy_types = {}
          insurables = @policy.insurables
          insurables.each do |insurable|
            policies = insurable.policies.where(status: %w[BOUND BOUND_WITH_WARNING])
            policies.each do |policy|
              active_policy_types[policy.policy_type_id] = policy
            end
          end

          active_policy_types.each do |policy_type, policy|
            if policy_type == PolicyType::MASTER_COVERAGE_ID
              policy.update(status: 10) # Cancel MASTER_COVERAGE child policy
            end
          end

          render json: @policy.to_json,
                 status: 202
        else
          render json: @policy.errors.to_json,
                 status: 422
        end
      end

      private

      def view_path
        super + '/policies'
      end

      def set_policy
        # @policy = access_model(::Policy, params[:id])
        @policy = Policy.find(params[:id])
        unless @policy.policy_in_system == false && ["EXTERNAL_UNVERIFIED", "EXTERNAL_VERIFIED", "EXTERNAL_REJECTED"].include?(@policy.status)
          render json: standard_error(error: "Invalid Selection", message: "This policy does not meet the criteria for review")
        end
      end

      def set_substrate
        super
        if @substrate.nil?
          # TO DO: why there was poliy_in_system == false? if it verified we need to change status to true?
          @substrate = access_model(::Policy.where(policy_in_system: false, status: ["EXTERNAL_UNVERIFIED", "EXTERNAL_VERIFIED", "EXTERNAL_REJECTED"]))
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

      def update_policy_attributes
        params.require(:policy).permit(:id, :number, :out_of_system_carrier_title, :status, :number, :out_of_system_carrier_title,
                      :system_data => { :rejection_reasons => []},
                      policy_coverages_attributes: %i[id title designation limit])
      end

    end
  end
end
