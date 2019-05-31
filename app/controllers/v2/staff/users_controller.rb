##
# V1 Account Users Controller
# file: app/controllers/v1/account/users_controller.rb

module V2
  module Staff
    class UsersController < StaffController
      before_action :set_user,
        only: [:show, :update]

      def index
        super(:@users, @account.users, :profile)
      end

      def show
        logger.debug @user.to_json
      end

      def new
      end

      def create
        # handle users that already exist
        if user_params[:email] && !(@user = ::User.where(email: user_params[:email]).take).nil?
          if (@acctu = @user.account_users.where(account_id: current_staff.account_id).take).nil?
            # user exists, but not in association with this account
            if @user.update_as(current_staff, {account_users_attributes: [{ account_id: current_staff.account_id }]})
              render :show, status: :created
            else
              render json: @user.errors,
                status: :unprocessable_entity
            end
          else
            # user exists in association with this account
            if @acctu.status != 'enabled'
              @acctu.update(status: 'enabled')
              render :show, status: :created
            else
              render json: { email: ['has already been taken'] },
                status: :unprocessable_entity
            end
          end
          return
        end
        # handle creating new users
        @user = ::User.new(user_params.merge(account_users_attributes: [{ account_id: current_staff.account_id }]))
        if @user.invite_as!(current_staff, send_invite: (params["invite"] == true || params["invite"] == "true" ? true : false))
          render :show, status: :created
        else
          render json: @user.errors,
            status: :unprocessable_entity
        end
      end

      def update
        if @user.update_as(current_staff, user_params)
          render :show, status: :ok
        else
          render json: @user.errors,
            status: :unprocessable_entity
        end
      end

      private

        def view_path
          super + '/users'
        end

        def user_params
          params.require(:user).permit(:email, :time_zone,
                                        profile_attributes: [
                                          :id, :first_name, :middle_name, :last_name,
                                          :contact_email, :contact_phone, :birth_date
                                        ])
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            email: [ :scalar, :array, :like ],
            guest: [ :scalar ],
            current_payment_method: [ :scalar, :array ],
            profile: {
              first_name: [ :scalar, :like ],
              last_name: [ :scalar, :like ]
            }
          }
        end

        def set_user
          @user = @account.users.find(params[:id])
        end
    end
  end
end
