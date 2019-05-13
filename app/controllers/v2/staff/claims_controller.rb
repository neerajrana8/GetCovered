##
# V1 Account Claims Controller
# file: app/controllers/v1/account/claims_controller.rb

module V1
  module Account
    class ClaimsController < StaffController
      before_action :set_claim, only: [:show, :update]
      before_action :only_super_admins, only: :destroy
      
      def index
        if params[:short]
          super(:@claims, @scope_association.claims)
        else
          # super(:@claims, @account.claims, unit: {building: :community})
        end
      end

      def show
      end

      def create
        @claim = current_staff.claims.new(claim_create_params)
        if @claim.save
          render :show, status: :created
        else
          render json: @claim.errors,
            status: :unprocessable_entity
        end
      end

      def update
        if @claim.status != "submitted"
          @claim.errors[:base] << "Only claims which have not yet been received may be modified."
        end
        if @claim.errors.empty? && @claim.update_as(current_staff, claim_update_params)
          render :show, status: :ok
        else
          render json: @claim.errors,
            status: :unprocessable_entity
        end
      end

      private

        def view_path
          super + '/claims'
        end

        def claim_create_params
          params.require(:claim).permit(:subject, :description, :date_of_loss)
        end

        def claim_update_params
          params.require(:claim).permit(:subject, :description, :date_of_loss)
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            date_of_loss: [:array, :interval],
            type_of_loss: [:scalar, :array],
            status: [:scalar, :array],
            claimant_id: [:scalar, :array],
            claimant_type: [:scalar, :array],
            claimable_id: [:scalar, :array],
            claimable_type: [:scalar, :array],
            master_policy_id: [:scalar, :array],
            unit_id: [:scalar, :array],
            unit: {
              id: [ :scalar, :array ],
              mailing_id: [ :sort_only ],
              building_id: [ :scalar, :array ],
              building: {
                id: [ :scalar, :array ],
                name: [ :sort_only ],
                community_id: [ :scalar, :array ],
                community: {
                  name: [ :sort_only ],
                  id: [ :scalar, :array ],
                  account_id: [ :scalar, :array ]
                }
              }
            }
          }
        end

        def set_claim
          if current_staff.super_admin?
            @claim = Claim.find(params[:id])
          else
            @claim = @scope_association.claims.find(params[:id])
          end
        end

    end
  end
end
