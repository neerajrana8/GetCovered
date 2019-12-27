##
# V2 StaffAgency Users Controller
# File: app/controllers/v2/staff_agency/users_controller.rb

module V2
  module StaffAgency
    class UsersController < StaffAgencyController
      before_action :set_user, only: %i[update show]

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

      def create
        if create_allowed?
          @user = ::User.new(create_params)
          # remove password issues from errors since this is a Devise model
          @user.valid? if @user.errors.blank?
          @user.errors.messages.except!(:password)
          if @user.errors.none? && @user.invite_as(current_staff)
            render :show,
              status: :created
          else
            render json: @user.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def update
        if update_allowed?
          if @user.update_as(current_staff, update_params)
            render :show,
              status: :ok
          else
            render json: @user.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      private

      def view_path
        super + '/users'
      end

      def create_allowed?
        true
      end

      def update_allowed?
        true
      end

      def set_user
        @user = current_staff.organizable.active_users.find_by(id: params[:id])
      end

      def create_params
        return({}) if params[:user].blank?

        to_return = params.require(:user).permit(
          :email, :enabled, notification_options: {}, settings: {},
                            profile_attributes: %i[
                              birth_date contact_email contact_phone first_name
                              job_title last_name middle_name suffix title
                            ]
        )
        to_return
      end

      def update_params
        return({}) if params[:user].blank?

        params.require(:user).permit(
          :enabled, notification_options: {}, settings: {},
                    profile_attributes: %i[
                      birth_date contact_email contact_phone first_name
                      job_title last_name middle_name suffix title
                    ]
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
  end # module StaffAgency
end
