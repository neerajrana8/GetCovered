##
# V2 StaffSuperAdmin ModulePermissions Controller
# File: app/controllers/v2/staff_super_admin/module_permissions_controller.rb

module V2
  module StaffSuperAdmin
    class ModulePermissionsController < StaffSuperAdminController
      
      before_action :set_module_permission,
        only: [:update, :show]
            
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@module_permissions)
        else
          super(:@module_permissions)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @module_permission = @substrate.new(create_params)
          if !@module_permission.errors.any? && @module_permission.save
            render :show,
              status: :created
          else
            render json: @module_permission.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @module_permission.update(update_params)
            render :show,
              status: :ok
          else
            render json: @module_permission.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/module_permissions"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_module_permission
          @module_permission = access_model(::ModulePermission, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::ModulePermission)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.module_permissions
          end
        end
        def create_params
          return({}) if params[:module_permission].blank?
          to_return = {}
          return(to_return)
        end
        
        def update_params
          return({}) if params[:module_permission].blank?
          to_return = {}
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
