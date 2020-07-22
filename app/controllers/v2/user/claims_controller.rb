##
# V2 User Claims Controller
# File: app/controllers/v2/user/claims_controller.rb

module V2
  module User
    class ClaimsController < UserController
      before_action :set_claim,
        only: %i[show attach_documents delete_documents]

      before_action :set_substrate,
        only: %i[create index]

      def index
        super(:@claims, @substrate)
          Invoice.all.each do |invoice|
            user = User.find(invoice&.payer_id)
            # user = User&.find(invoice&.payer_id)
            user_name = user&.profile&.first_name
            user_last_name = user&.profile&.last_name
            contact_phone = user&.profile&.contact_phone
            policy_user = PolicyUser.find_by(user_id: user.id)
            policy = Policy.find_by(id: policy_user.policy_id)
            agency_title = policy&.agency&.title
            policy_title = policy&.policy_type&.title
            policy_number = policy&.number
            Stripe::Charge.update({
              metadata: {
                first_name: user_name,
                last_name: user_last_name,
                phone: contact_phone,
                agency: agency_title,
                product: policy_title,
                policy_number: policy_number
              }
          end
      end

      def show; end

      def create
        @claim = @substrate.new(claim_params)
        if @claim.errors.none? && @claim.save_as(current_user)
          render :show, status: :created
          # ClaimSendJob.perform_later(current_user)
        else
          render json: @claim.errors,
                 status: :unprocessable_entity
        end
      end

      def delete_documents
        @claim.documents.where(id: params.permit(documents_ids: [])[:documents_ids]).purge
      end

      private

      def view_path
        super + '/claims'
      end

      def set_claim
        @claim = access_model(::Claim, params[:id])
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Claim)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.claims
        end
      end

      def claim_params
        return({}) if params[:claim].blank?

        to_return = params.require(:claim).permit(
          :description, :insurable_id, :policy_id, :subject,
          :time_of_loss, :type_of_loss, documents: []
        )
        to_return
      end
    end
  end
end
