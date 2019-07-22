module V2
  module Staff
    class ModulePermissionsController < StaffController
      before_action :only_super_admins
      before_action :set_module_permission, only: [:show, :update, :destroy]
      
      def index
        @module_permissions = ModulePermission.all
      end
      
      def show
      end
      
      def create
        @module_permission = ModulePermission.new(module_permission_params)
        
        if @module_permission.save
          render :show, status: :created, location: @module_permission
        else
          render json: @module_permission.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @module_permission.update(module_permission_params)
          render :show, status: :ok, location: @module_permission
        else
          render json: @module_permission.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @module_permission.destroy
      end
      
      private
      def set_module_permission
        @module_permission = ModulePermission.find(params[:id])
      end
      
      def module_permission_params
        params.require(:module_permission)
              .permit(:application_module_id, :permissable_id, :permissable_type)
      end
    end
  end
end
