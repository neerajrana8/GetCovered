##
# V2 StaffSuperAdmin CarrierInsurableTypes Controller
# File: app/controllers/v2/staff_super_admin/carrier_insurable_types_controller.rb

module V2
  module StaffSuperAdmin
    class CarrierInsurableTypesController < StaffSuperAdminController
      
      before_action :set_carrier_insurable_type,
        only: [:update, :show]
      
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@carrier_insurable_types, @substrate)
        else
          super(:@carrier_insurable_types, @substrate)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @carrier_insurable_type = @substrate.new(create_params)
          if !@carrier_insurable_type.errors.any? && @carrier_insurable_type.save
            render :show,
              status: :created
          else
            render json: @carrier_insurable_type.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @carrier_insurable_type.update(update_params)
            render :show,
              status: :ok
          else
            render json: @carrier_insurable_type.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/carrier_insurable_types"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_carrier_insurable_type
          @carrier_insurable_type = access_model(::CarrierInsurableType, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::CarrierInsurableType)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.carrier_insurable_types
          end
        end
        
        def create_params
          return({}) if params[:carrier_insurable_type].blank?
          to_return = params.require(:carrier_insurable_type).permit(
            :carrier_id, :enabled, :insurable_type_id, profile_data: {},
            profile_traits: {}
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:carrier_insurable_type].blank?
          params.require(:carrier_insurable_type).permit(
            :enabled, profile_data: {}, profile_traits: {}
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
