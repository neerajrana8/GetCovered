##
# V2 StaffSuperAdmin Users Controller
# File: app/controllers/v2/staff_super_admin/users_controller.rb

module V2
  module StaffSuperAdmin
    class UsersController < StaffSuperAdminController
      
      before_action :set_user, only: %i[show update]
      
      def index

        query = ::User.all
        if params[:community_like]
          communities = Insurable.where(insurable_type_id: InsurableType::COMMUNITIES_IDS).where("title ILIKE ?", "%#{params[:community_like]}%")
          unit_ids = communities.map{ |c| c.units.pluck(:id) }.flatten
          policy_ids = PolicyInsurable.where(insurable_id: unit_ids).pluck(:policy_id)
          query = query.references(:policy_users).includes(:policy_users).where(policy_users: { policy_id: policy_ids })
        end

        super(:@users, query, :profile, :accounts, :agencies)
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
          email: %i[scalar array like],
          profile: {
            full_name: %i[scalar array like]
          },
          policies: {
            account: {
              title: %i[scalar array like]
            }
          },
          accounts: { agency_id: %i[scalar array], id: %i[scalar array] }
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
