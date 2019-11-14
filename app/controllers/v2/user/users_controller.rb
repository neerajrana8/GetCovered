##
# V2 User Users Controller
# File: app/controllers/v2/user/users_controller.rb

module V2
  module User
    class UsersController < UserController
      before_action :set_user,
                    only: %i[update show]

      def show; end

      def update
        if update_allowed?
          if @user.update_as(current_user, update_params)
            render :show, status: :ok
          else
            render json: @user.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end

      private

      def view_path
        super + '/users'
      end

      def update_allowed?
        true
      end

      def set_user
        @user = access_model(::User, params[:id])
      end

      def update_params
        return({}) if params[:user].blank?

        params.require(:user).permit(
          notification_options: {}, settings: {},
          profile_attributes: %i[
            birth_date contact_email contact_phone first_name
            job_title last_name middle_name suffix title
          ]
        )
      end
    end
  end
end
