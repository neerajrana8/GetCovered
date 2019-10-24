##
# V2 StaffAccount Claims Controller
# File: app/controllers/v2/staff_account/claims_controller.rb

module V2
  module StaffAccount
    class ClaimsController < StaffAccountController
      
      before_action :set_claim,
        only: [:update, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@claims, @substrate)
        else
          super(:@claims, @substrate, :insurable, :policy)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @claim = @substrate.new(create_params)
          if !@claim.errors.any? && @claim.save_as(current_staff)
            render :show,
              status: :created
          else
            render json: @claim.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @claim.update_as(current_staff, update_params)
            render :show,
              status: :ok
          else
            render json: @claim.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/claims"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
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
        
        def create_params
          return({}) if params[:claim].blank?
          to_return = params.require(:claim).permit(
            :claimant_id, :claimant_type, :description, :insurable_id,
            :policy_id, :subject, :time_of_loss
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:claim].blank?
          params.require(:claim).permit(
            :description, :insurable_id, :policy_id, :subject,
            :time_of_loss
          )
        end
        
        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffAccount
end
