##
# V2 StaffSuperAdmin CarrierPolicyTypes Controller
# File: app/controllers/v2/staff_super_admin/carrier_policy_types_controller.rb

module V2
  module StaffSuperAdmin
    class CarrierPolicyTypesController < StaffSuperAdminController
      
      before_action :set_carrier_policy_type,
        only: [:update, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@carrier_policy_types, @substrate)
        else
          super(:@carrier_policy_types, @substrate)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @carrier_policy_type = @substrate.new(create_params)
          if !@carrier_policy_type.errors.any? && @carrier_policy_type.save
            render :show,
              status: :created
          else
            render json: @carrier_policy_type.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @carrier_policy_type.update(update_params)
            render :show,
              status: :ok
          else
            render json: @carrier_policy_type.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/carrier_policy_types"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_carrier_policy_type
          @carrier_policy_type = access_model(::CarrierPolicyType, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::CarrierPolicyType)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.carrier_policy_types
          end
        end
        
        def create_params
          return({}) if params[:carrier_policy_type].blank?
          to_return = params.require(:carrier_policy_type).permit(
            :application_required, :carrier_id, :policy_type_id,
            application_fields: [], application_questions: [],
            policy_defaults: {}
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:carrier_policy_type].blank?
          params.require(:carrier_policy_type).permit(
            :application_required, :carrier_id, :policy_type_id,
            application_fields: [], application_questions: [],
            policy_defaults: {}
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
  end # module StaffSuperAdmin
end
