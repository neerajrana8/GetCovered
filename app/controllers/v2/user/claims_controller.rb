##
# V2 User Claims Controller
# File: app/controllers/v2/user/claims_controller.rb

module V2
  module User
    class ClaimsController < UserController
      before_action :set_claim,
        only: [:show]

      before_action :set_substrate,
        only: [:create, :index]

      def index
        super(:@claims, @substrate)
      end

      def show
        render json: @claim
      end

      def create
        @claim = @substrate.new(claim_params)
        if @claim.errors.none? && @claim.save_as(current_user)
          render json: @claim,
                 status: :created
        else
          render json: @claim.errors,
                 status: :unprocessable_entity
        end
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
          :time_of_loss
        )
        to_return
      end
    end
  end
end
