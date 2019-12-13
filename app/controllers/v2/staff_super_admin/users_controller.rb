##
# V2 StaffSuperAdmin Users Controller
# File: app/controllers/v2/staff_super_admin/users_controller.rb

module V2
  module StaffSuperAdmin
    class UsersController < StaffSuperAdminController
      
      before_action :set_user,
        only: [:show]
      
      def index
        super(:@users, current_staff.organizable.active_users, :profile)
      end

      def show
        if @user
          render :show, status: :ok
        else
          render json: { user: 'not found' }, status: :not_found
        end
      end
      
      
      private
      
      def view_path
        super + '/users'
      end

      def set_user
        @user = current_staff.organizable.active_users.find_by(id: params[:id])
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
