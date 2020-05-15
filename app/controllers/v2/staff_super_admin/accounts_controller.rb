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
        account = Account.includes(:policies).find(params[:id])
        @account_policies = paginator(account.policies)
        render '/v2/staff_super_admin/accounts/account_policies', status: :ok
      end

      def account_communities
        account = Account.includes(:insurables).find(params[:id])
        @account_communities = paginator(Insurable.where(account_id: account.id).communities)
        render '/v2/staff_super_admin/accounts/account_communities', status: :ok
      end

      def account_buildings
        account = Account.includes(:insurables).find(params[:id])
        @account_buildings = paginator(Insurable.where(account_id: account.id).buildings)
        render '/v2/staff_super_admin/accounts/account_buildings', status: :ok
      end

      def account_units
        account = Account.includes(:insurables).find(params[:id])
        @account_units = paginator(Insurable.where(account_id: account.id).units)
        render '/v2/staff_super_admin/accounts/account_units', status: :ok
      end

      def show
        render :show, status: :ok
      end

      private

      def view_path
        super + '/accounts'
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
          id: %i[scalar array],
          agency: {
            title: %i[scalar like]
          },
          agency_id: %i[scalar array],
          owner: {
            profile: {
              contact_phone: %i[scalar like],
              contact_email: %i[scalar like]
            }
          },
          enabled: [:scalar],
          addresses: {
            state: %i[scalar array like],
            city: %i[scalar array like],
            zip_code: %i[scalar array]
          }
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffSuperAdmin
end
