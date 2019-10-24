##
# V2 StaffSuperAdmin Users Controller
# File: app/controllers/v2/staff_super_admin/users_controller.rb

module V2
  module StaffSuperAdmin
    class UsersController < StaffSuperAdminController
      
      before_action :set_user,
        only: [:show]
            
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@users, @substrate, :profile)
        else
          super(:@users, @substrate, :profile)
        end
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/users"
        end
        
        def set_user
          @user = access_model(::User, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::User)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.users
          end
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
