##
# V2 User Users Controller
# File: app/controllers/v2/user/users_controller.rb

module V2
  module User
    class UsersController < UserController
      before_action :set_user, only: %i[update show change_password]
      before_action :correct_user, only: %i[update show change_password]

      def show; end

      def change_password
        binding.pry
        if @user.update_with_password(update_params) #TODO: valid_password? not working :( because of invitable and database authenthicable
          # Sign in the user by passing validation in case their password changed
          bypass_sign_in(@user)
          render :show, status: :ok
        else
          render json: { success: false, errors: @user.errors }, status: :unprocessable_entity
        end
      end

      def update
        if @user.update_as(current_user, update_params)
          render :show, status: :ok
        else
          render json: @user.errors, status: :unprocessable_entity
        end
      end

      private

      def view_path
        super + '/users'
      end

      def correct_user
        if @user != current_user
          render json: { success: false, errors: [I18n.t('user_users_controler.unauthorized_access')] }, status: :unauthorized
        end
      end

      def update_allowed?
        true if @user.id == current_user.id
      end

      def set_user
        @user = ::User.find(params[:id])
      end

      def update_params
        return({}) if params[:user].blank?

        params.require(:user).permit(
          :current_password, :password, :password_confirmation,
          notification_options: {},
          settings: {},
          profile_attributes: %i[
            birth_date contact_email contact_phone first_name language
            job_title last_name middle_name suffix title gender salutation
          ],
          address_attributes: %i[city country state street_name street_two zip_code]
        )
      end
    end
  end
end
