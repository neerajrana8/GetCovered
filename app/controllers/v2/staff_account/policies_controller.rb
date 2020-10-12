##
# V2 StaffAccount Policies Controller
# File: app/controllers/v2/staff_account/policies_controller.rb

module V2
  module StaffAccount
    class PoliciesController < StaffAccountController

      include PoliciesMethods

      before_action :set_policy, only: [:update, :show, :update_coverage_proof, :delete_policy_document]
      
      before_action :set_substrate, only: [:index]
      
      def index
        super(:@policies, @substrate)
      end

      def search
        @policies = ::Policy.search(params[:query]).records.where(account_id: current_staff.organizable_id)
        render json: @policies.to_json, status: 200
      end
      
      def show
      end

      def resend_policy_documents
        ::Policies::SendProofOfCoverageJob.perform_later(params[:id])
        render json: { message: 'Documents were sent' }
      end

      private
      
        def view_path
          super + "/policies"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_policy
          @policy = access_model(::Policy, params[:id])
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
  end # module StaffAccount
end
