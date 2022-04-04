##
# V2 StaffSuperAdmin Policies Controller
# File: app/controllers/v2/staff_super_admin/policies_controller.rb

module V2
  module StaffPolicySupport
    class PoliciesController < StaffPolicySupportController
      include PoliciesMethods

      MAX_COUNTS = 9998

      before_action :set_policy,
                    only: %i[update show]
      before_action :set_optional_coverages, only: [:show]

      before_action :set_substrate, only: [:index]

      def index
        super(:@policies, @substrate, :agency, :account, :primary_user)
      end

      def show
        if @policy.primary_insurable.nil?
          @min_liability = 1000000
          @max_liability = 30000000
        else
          insurable = @policy.primary_insurable.parent_community
          account = insurable.account
          carrier_id = account.agency.providing_carrier_id(PolicyType::RESIDENTIAL_ID, insurable){|cid| (insurable.get_carrier_status(carrier_id) == :preferred) ? true : nil }
          carrier_policy_type = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take
          uid = (carrier_id == ::MsiService.carrier_id ? '1005' : carrier_id == ::QbeService.carrier_id ? 'liability' : nil)
          liability_options = ::InsurableRateConfiguration.get_inherited_irc(carrier_policy_type, account, insurable).configuration['coverage_options']&.[](uid)&.[]('options')
          @max_liability = liability_options&.map{|opt| opt['value'].to_i }&.max
          @min_liability = liability_options&.map{|opt| opt['value'].to_i }&.min
        end

        if @min_liability.nil? || @min_liability == 0 || @min_liability == "null"
          @min_liability = 1000000
        end

        if @max_liability.nil? || @max_liability == 0 || @max_liability == "null"
          @max_liability = 30000000
        end
      end

      def update
        if @policy.update(update_policy_attributes)
          PmTenantPortal::InvitationToPmTenantPortalMailer.external_policy_declined(policy: @policy).deliver_now if update_policy_attributes[:status] == "EXTERNAL_REJECTED"
          PmTenantPortal::InvitationToPmTenantPortalMailer.external_policy_accepted(policy: @policy).deliver_now if update_policy_attributes[:status] == "EXTERNAL_VERIFIED"
          render json: @policy.to_json,
                 status: 202
        else
          render json: @policy.errors.to_json,
                 status: 422
        end
      end

      def default_pagination_per
        MAX_COUNTS
      end

      def maximum_pagination_per
        MAX_COUNTS
      end

      private

      def view_path
        super + '/policies'
      end

      def set_policy
        @policy = access_model(::Policy, params[:id])
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
        system_data_keys = params.require(:policy)
                                 .fetch(:system_data, {})
                                 .keys

        params.require(:policy)
              .permit(:id, :policy_number, :out_of_system_carrier_title, :status, :number, :out_of_system_carrier_title,
                      :system_data => system_data_keys,
                      policy_coverages_attributes: %i[title designation limit])
      end

    end
  end
end
