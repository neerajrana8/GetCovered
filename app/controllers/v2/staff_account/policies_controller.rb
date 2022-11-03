##
# V2 StaffAccount Policies Controller
# File: app/controllers/v2/staff_account/policies_controller.rb

module V2
  module StaffAccount
    class PoliciesController < StaffAccountController
      include PoliciesMethods

      before_action :set_policy,
                    only: %i[
                      update show update_coverage_proof delete_policy_document refund_policy 
                      cancel_policy get_leads add_policy_documents]
      before_action :set_optional_coverages, only: [:show]
      

      before_action :set_substrate, only: [:index]

      def index
        super(:@policies, @substrate)
      end

      def search
        @policies = ::Policy.search(params[:query]).records.where(account_id: current_staff.organizable_id)
        render json: @policies.to_json, status: 200
      end

      def show; end

      def resend_policy_documents
        ::Policies::SendProofOfCoverageJob.perform_later(params[:id])
        render json: { message: 'Documents were sent' }
      end

      def get_leads
        @leads = [@policy.primary_user.lead]
        @site_visits=@leads.last.lead_events.order("DATE(created_at)").group("DATE(created_at)").count.keys.size
        render 'v2/shared/leads/leads_by_policy'
      end
      
      def refund_policy
        render json: standard_error(:refund_policy_error, "Dashboard cancellation facilities disabled for maintenance", nil)
      end
      
      def cancel_policy
        render json: standard_error(:cancel_policy_error, "Dashboard cancellation facilities disabled for maintenance", nil)
      end

      private

      def view_path
        super + '/policies'
      end

      def create_allowed?
        true
      end

      def update_allowed?
        true
      end

      def set_policy
        # NOTE: Need refactoring, access_model returns nil
        # @policy = access_model(::Policy, params[:id])
        @policy = Policy.find(params[:id])
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
