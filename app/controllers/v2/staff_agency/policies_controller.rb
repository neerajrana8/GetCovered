##
# V2 StaffAgency Policies Controller
# File: app/controllers/v2/staff_agency/policies_controller.rb

module V2
  module StaffAgency
    class PoliciesController < StaffAgencyController
      include PoliciesMethods
      before_action :set_policy,
                    only: %i[update show update_coverage_proof delete_policy_document refund_policy cancel_policy add_policy_documents]
      before_action :set_optional_coverages, only: [:show]
      before_action :set_substrate, only: %i[create index add_coverage_proof]
      check_privileges 'policies.policies'

      def index
        relation =
          if current_staff.getcovered_agent? && params[:agency_id].nil?
            Policy.all
          else
            Policy.where(agency: @agency)
          end

        super(:@policies, relation, :account, :primary_user, :policy_type)
      end

      def search
        @policies =
          if current_staff.getcovered_agent? && params[:agency_id].nil?
            Policy.search(params[:query]).records
          else
            Policy.search(params[:query]).records.where(agency_id: @agency)
          end
        render json: @policies.to_json, status: 200
      end
      
      def show; end

      def resend_policy_documents
        ::Policies::SendProofOfCoverageJob.perform_later(params[:id])
        render json: { message: 'Documents were sent' }
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
        @policy =
          if current_staff.getcovered_agent? && params[:agency_id].nil?
            Policy.find(params[:id])
          else
            @agency.policies.find(params[:id])
          end
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
