##
# V2 StaffSuperAdmin Accounts Controller
# File: app/controllers/v2/staff_super_admin/accounts_controller.rb

module V2
  module StaffSuperAdmin
    class AccountsController < StaffSuperAdminController

      before_action :set_account,
                    only: [:show]

      before_action :set_substrate,
                    only: [:index]

      def index
        if params[:short]
          super(:@accounts, Account)
        else
          super(:@accounts, Account, :agency)
        end
      end

      def account_policies
        account = Account.includes(:polices).find(params[:id])
        @account_policies = account.policies || []
        render "/v2/staff_super_admin/accounts/account_policies", status: :ok
      end

      def show
        render :show, status: :ok
      end

      private

      def view_path
        super + "/accounts"
      end

      def set_account
        @account = Account.find_by(id: params[:id])
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Account)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.accounts
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: [:scalar, :array],
          agency: {
            title: [:scalar, :like],
          },
          agency_id: [:scalar, :array],
          owner: {
            profile: {
              contact_phone: [:scalar, :like],
              contact_email: [:scalar, :like]
            }
          },
          enabled: [:scalar],
          addresses: {
            state: [:scalar, :array, :like],
            city: [:scalar, :array, :like],
            zip_code: [:scalar, :array]
          }
        }
      end

      def supported_orders
        supported_filters(true)
      end

    end
  end # module StaffSuperAdmin
end
