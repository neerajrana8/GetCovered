##
# V2 StaffAccount Policies Controller
# File: app/controllers/v2/staff_account/policies_controller.rb

module V2
  module StaffAccount
    class PoliciesController < StaffAccountController
      
      before_action :set_policy,
        only: [:update, :show]
      
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@policies, @substrate)
        else
          super(:@policies, @substrate)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @policy = @substrate.new(create_params)
          if !@policy.errors.any? && @policy.save
            render :show,
              status: :created
          else
            render json: @policy.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @policy.update(update_params)
            render :show,
              status: :ok
          else
            render json: @policy.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
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
        
        def create_params
          return({}) if params[:policy].blank?
          to_return = params.require(:policy).permit(
            :account_id, :agency_id, :auto_renew, :cancellation_code,
            :cancellation_date_date, :carrier_id, :effective_date,
            :expiration_date, :number, :policy_type_id, :status
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:policy].blank?
          params.require(:policy).permit(
            :cancellation_code, :cancellation_date_date,
            :effective_date, :expiration_date, :number, :policy_type_id,
            :status
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
