# frozen_string_literal: true

# V1 User Users Controller
# file: app/controllers/v1/user/users_controller.rb

module V1
  module User
    class UsersController < UserController
      before_action :set_user

      def show; end

      def update
        if @user.update(user_params)
          render :show, status: :ok
        else
          render json: @user.errors,
                 status: :unprocessable_entity
        end
      end

      def set_payment_method
        if params[:token].blank?
          render json: { error: 'payment token is required' },
                 status: :unprocessable_entity
          return
        end
        if @user.attach_payment_source(params[:token])
          @user.reload
          render :show, status: :ok
        else
          render json: @user.errors,
                 status: :unprocessable_entity
        end
      end

      def verify_ach
        successful = false
        if params.key?(:verification_one) && params.key?(:verification_two)
          successful = @user.verify_ach(params[:verification_one], params[:verification_two])
        end
        if successful
          @user.reload
          render :show, status: :ok
        else
          render json: @user.errors, status: :unprocessable_entity
        end
      end

      def save_card
        unless params[:stripe_token].blank?
          if @user.set_stripe_id(params[:stripe_token])
            render :blank, status: :ok
          end
        end
      end

      private

      def view_path
        super + '/users'
      end

      def user_params
        params.require(:user).permit(:email, profile_attributes: %i[
                                       id first_name middle_name last_name
                                       contact_email contact_phone birth_date
                                     ])
      end

      def set_user
        @user = current_user
      end
    end
  end
end
