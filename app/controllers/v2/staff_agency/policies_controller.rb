##
# V2 StaffAgency Policies Controller
# File: app/controllers/v2/staff_agency/policies_controller.rb

module V2
  module StaffAgency
    class PoliciesController < StaffAgencyController
      
      before_action :set_policy, only: %i[update show refund_policy cancel_policy]

      include PoliciesMethods

      before_action :set_policy, only: %i[update show update_coverage_proof delete_policy_document]

      before_action :set_substrate, only: [:create, :index, :add_coverage_proof]
      
      def index
        if current_staff.getcovered_agent? && params[:agency_id].nil?
          super(:@policies, Policy.all)
        else
          super(:@policies, Policy.where(agency: @agency))
        end
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
        @policy.cancel('manual_cancellation_with_refunds', Time.zone.now.to_date)
        if @policy.errors.any?
          render json: standard_error(:refund_policy_error, nil, @policy.errors.full_messages)
        else
          render :show, status: :ok
        end
      end

      def cancel_policy
        @policy.cancel('manual_cancellation_without_refunds', Time.zone.now.to_date)
        if @policy.errors.any?
          render json: standard_error(:cancel_policy_error, nil, @policy.errors.full_messages)
        else
          render :show, status: :ok
        end
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
      end

    end
  end
end
