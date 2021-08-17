##
# V2 StaffSuperAdmin Users Controller
# File: app/controllers/v2/staff_super_admin/users_controller.rb

module V2
  module StaffSuperAdmin
    class UsersController < StaffSuperAdminController
      
      before_action :set_user, only: %i[show update]
      
      def index
        super(:@users, ::User.all, :profile, :accounts, :agencies, :account_users, :policy_users, :lease_users)
        render template: 'v2/shared/users/index', status: :ok
      end

      def show
        if @user
          render template: 'v2/shared/users/show', status: :ok
        else
          render json: { user: 'not found' }, status: :not_found
        end
      end

      def update
        if @user.update_as(current_staff, update_params)
          render template: 'v2/shared/users/show', status: :ok
        else
          render json: @user.errors, status: :unprocessable_entity
        end
      end
      
      private
      
      def view_path
        super + '/users'
      end

      def set_user
        @user = ::User.all.find_by(id: params[:id])
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          created_at: %i[scalar array interval],
          updated_at: %i[scalar array interval],
          accounts: { agency_id: %i[scalar array], id: %i[scalar array] },
          profile: {
            first_name: %i[scalar like],
            last_name: %i[scalar like],
            full_name: %i[scalar like]
          }
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def update_params
        return({}) if params[:user].blank?

        params.require(:user).permit(
          :enabled, notification_options: {}, settings: {},
                    profile_attributes: %i[
                      birth_date contact_email contact_phone first_name
                      job_title last_name middle_name suffix title gender salutation
                    ]
        )
      end
    end
  end # module StaffSuperAdmin
end
