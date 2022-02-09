##
# V2 StaffAccount Users Controller
# File: app/controllers/v2/staff_account/users_controller.rb

module V2
  module StaffAccount
    class UsersController < StaffAccountController

      before_action :set_user,
        only: [:update, :show]

      before_action :set_substrate,
        only: [:create, :index]

      def index
        if params[:short]
          super(:@users, :profile)
        else
          super(:@users, :profile)
        end
      end

      def show
      end

      def create
        if create_allowed?
          @user = @substrate.new(create_params)
          # remove password issues from errors since this is a Devise model
          @user.valid? if @user.errors.blank?
          #because it had FrozenError (can't modify frozen Hash: {:password=>["can't be blank"]}):
          #@user.errors.messages.except!(:password)
          if (!@user.errors.any?|| only_password_blank_error?(@user.errors) ) && @user.invite_as!(current_staff)
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

        def only_password_blank_error?(user_errors)
          user_errors.messages.keys == [:password]
        end

        def view_path
          super + "/users"
        end

        def create_allowed?
          true
        end

        def update_allowed?
          true
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
        def create_params
          return({}) if params[:user].blank?
          to_return = params.require(:user).permit(
            :email, :enabled, notification_options: {}, settings: {},
            profile_attributes: [
              :birth_date, :contact_email, :contact_phone, :first_name,
              :job_title, :last_name, :middle_name, :suffix, :title
            ]
          )
          return(to_return)
        end

        def update_params
          return({}) if params[:user].blank?
          params.require(:user).permit(
            :enabled, notification_options: {}, settings: {},
            profile_attributes: [
              :birth_date, :contact_email, :contact_phone, :first_name,
              :job_title, :last_name, :middle_name, :suffix, :title
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
  end # module StaffAccount
end
