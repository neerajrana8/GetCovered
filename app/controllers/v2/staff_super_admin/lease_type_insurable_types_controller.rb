##
# V2 StaffSuperAdmin LeaseTypeInsurableTypes Controller
# File: app/controllers/v2/staff_super_admin/lease_type_insurable_types_controller.rb

module V2
  module StaffSuperAdmin
    class LeaseTypeInsurableTypesController < StaffSuperAdminController
      
      before_action :set_lease_type_insurable_type,
        only: [:update, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@lease_type_insurable_types)
        else
          super(:@lease_type_insurable_types)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @lease_type_insurable_type = @substrate.new(create_params)
          if !@lease_type_insurable_type.errors.any? && @lease_type_insurable_type.save
            render :show,
              status: :created
          else
            render json: @lease_type_insurable_type.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @lease_type_insurable_type.update(update_params)
            render :show,
              status: :ok
          else
            render json: @lease_type_insurable_type.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def access_model
        model_class
      end
      
      
      private
      
        def view_path
          super + "/lease_type_insurable_types"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_lease_type_insurable_type
          @lease_type_insurable_type = access_model(::LeaseTypeInsurableType, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::LeaseTypeInsurableType)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.lease_type_insurable_types
          end
        end
        def create_params
          return({}) if params[:lease_type_insurable_type].blank?
          to_return = params.require(:lease_type_insurable_type).permit(
            :enabled, :insurable_type_id, :lease_type_id
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:lease_type_insurable_type].blank?
          params.require(:lease_type_insurable_type).permit(
            :enabled, :insurable_type_id, :lease_type_id
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
