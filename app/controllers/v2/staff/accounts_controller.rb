# V1 Account Accounts Controller
# file: app/controllers/v1/account/accounts_controller.rb

module V1
  module Staff
    class AccountsController < StaffController
      before_action :set_account, only: [:show, :update], if: -> { current_staff.agent? }
      before_action :only_agents, only: %i[index create]
      before_action :only_super_admins, only: [:destroy]

      def index
        if params[:short]
          super(:@accounts, @scope_association.accounts)
        else
          super(:@accounts, @scope_association.accounts, :address)
        end
      end

      def show
        @account ||= @scope_association
      end

      def create
        @account = @scope_association.accounts.new(account_params)
        if @account.save_as(current_staff)
          render :show, status: :created
        else
          render json: @account.errors,
            status: :unprocessable_entity
        end
      end

      def update
        if @account.update_as(current_staff, account_params)
          render :show, status: :ok
        else
          render json: @account.errors,
                 status: :unprocessable_entity
        end
      end

      private

      def view_path
        super + '/accounts'
      end

      def account_params
        params.require(:account)
              .permit(:title, contact_info: %i[contact_phone contact_phone_ext contact_email],
                              address_attributes: %i[
                                id street_number street_one
                                street_two locality county
                                region country postal_code plus_four
                              ])
      end

      def supported_filters
        {
          id: %i[scalar array],
          title: %i[scalar like],
          contact_phone: %i[scalar like],
          contact_email: %i[scalar like],
          address: {
            locality: %i[scalar array like],
            region: %i[scalar array like],
            postal_code: %i[scalar array]
          }
        }
      end
      
      def set_account
        @account = @scope_association.accounts.find(params[:id])
      end

    end
  end
end
