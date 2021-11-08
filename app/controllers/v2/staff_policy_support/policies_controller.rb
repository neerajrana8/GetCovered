##
# V2 StaffSuperAdmin Policies Controller
# File: app/controllers/v2/staff_super_admin/policies_controller.rb

module V2
  module StaffPolicySupport
    class PoliciesController < StaffPolicySupportController
      include PoliciesMethods

      before_action :set_policy,
                    only: %i[update show]
      before_action :set_optional_coverages, only: [:show]

      before_action :set_substrate, only: [:index]

      def index
        super(:@policies, @substrate, :agency, :account, :primary_user, :primary_insurable, :carrier, :policy_type, invoices: :line_items)
      end

      def show; end

      def update
        if @policy.update(update_policy_attributes)
          puts "Hooray!  God praise the Queen."
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
        @policy = access_model(::Policy, params[:id])
        unless @policy.policy_in_system == false && @policy.status == "EXTERNAL_UNVERIFIED"
          render json: standard_error(error: "Invalid Selection", message: "This policy does not meet the criteria for review")
        end
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Policy.where(policy_in_system: false, status: "EXTERNAL_UNVERIFIED"))
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

      end

    end
  end
end