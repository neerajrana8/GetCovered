##
# V2 User Policies Controller
# File: app/controllers/v2/user/policies_controller.rb

module V2
  module User
    class PoliciesController < UserController
      
      skip_before_action :authenticate_user!, only: [:bulk_decline, :render_eoi, :bulk_accept, :refund_policy]
      
      before_action :user_from_invitation_token, only: [:bulk_decline, :render_eoi, :bulk_accept]
      
      before_action :set_policy, only: [:show]
      
      before_action :set_substrate, only: [:index, :add_coverage_proof]
      
      def index
        if params[:short]
          super(:@policies, @substrate)
        else
          super(:@policies, @substrate)
        end
      end
      
      def show
      end
      
      def add_coverage_proof
        insurable = Insurable.find_by(id: params[:insurable_id])
        render json: { message: 'Need Insurable' }, status: :unprocessable_entity and return if insurable.nil?

        @policy = @substrate.new(coverage_proof_params)
        @policy.account = insurable.account
        @policy.policy_in_system = false
        @policy.policy_users.new(user_id: current_user.id)
        if @policy.save
          Insurables::UpdateCoveredStatus.run!(insurable: @policy.primary_insurable) if @policy.primary_insurable.present?
          render json: { message: 'Policy created' }, status: :created
        else
          render json: { message: 'Policy failed' }, status: :unprocessable_entity
        end
      end
      
      def delete_coverage_proof_documents
        @policy.documents.where(id: params.permit(documents_ids: [])[:documents_ids]).purge
      end
      
      def bulk_decline
        @policy = ::Policy.find(params[:id])
        render json: { errors: ['Unauthorized Access'] }, status: :unauthorized and return unless @policy.primary_user == @user
        
        render json: { errors: ["Policy was already #{@policy.declined ? 'declined' : 'accepted'}"] }, status: :not_acceptable and return unless @policy.declined.nil?
        
        @policy.bulk_decline
        render json: { message: 'Policy is declined' }
      end
      
      def bulk_accept
        @policy = ::Policy.find(params[:id])
        render json: { errors: ['Unauthorized Access'] }, status: :unauthorized and return unless @policy.primary_user == @user
        
        render json: { errors: ["Policy was already #{@policy.declined ? 'declined' : 'accepted'}"] }, status: :not_acceptable and return unless @policy.declined.nil?
        
        @policy.update_attribute(:declined, false)
        ::Policies::SendProofOfCoverageJob.perform_later(@policy.id)
        
        render json: { message: 'Policy is accepted. An email sent with attached Policy' }
      end

      def resend_policy_documents
        ::Policies::SendProofOfCoverageJob.perform_later(params[:id])
        render json: { message: 'Documents were sent' }
      end

      def refund_policy
        policy = Policy.find(params[:id])
        change_request = ChangeRequest.new(status: 'pending')
        if change_request.save
          render json: { message: 'Refund was successfully sent' }, status: :ok
        else
          render json: { message: 'Refund was not successfully sent' }, status: :unprocessable_entity
        end          
      end
      
      def render_eoi
        @policy = ::Policy.find(params[:id])
        render json: { errors: ['Unauthorized Access'] }, status: :unauthorized and return unless @policy.primary_user == @user
        
        render json: { errors: ["Policy was already #{@policy.declined ? 'declined' : 'accepted'}"] }, status: :not_acceptable and return unless @policy.declined.nil?
        
        render json: {
          evidence_of_insurance: render_to_string("/v2/pensio/evidence_of_insurance.html.erb", :layout => false),
          summary: render_to_string("/v2/pensio/summary.html.erb", :layout => false),
        }
      end
      
      
      private
      
      def view_path
        super + "/policies"
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
      
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end
      
      def supported_orders
        supported_filters(true)
      end
      
      def coverage_proof_params
        params.require(:policy).permit(:number,
          :account_id, :agency_id, :policy_type_id,
          :carrier_id, :effective_date, :expiration_date,
          :out_of_system_carrier_title, :address, documents: [],
          policy_users_attributes: [ :user_id ]
        )
      end
      
    end
  end # module User
end
