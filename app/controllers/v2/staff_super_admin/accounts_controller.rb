##
# V2 StaffSuperAdmin Accounts Controller
# File: app/controllers/v2/staff_super_admin/accounts_controller.rb

module V2
  module StaffSuperAdmin
    class AccountsController < StaffSuperAdminController
      before_action :set_account, only: %i[show update enable disable]

      before_action :set_substrate, only: [:index]

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

      def create
        @account = Account.new(account_params)

        if @account.errors.none? && @account.save_as(current_staff)
          render :show, status: :created
        else
          render json: @account.errors, status: :unprocessable_entity
        end
      end

      def update
        if @account.update_as(current_staff, account_params)
          render :show, status: :ok
        else
          render json: @account.errors, status: :unprocessable_entity
        end
      end


      def disable
        result = Accounts::Disable.run(account: @account)
        if result.valid?
          render :show, status: :ok
        else
          render json: standard_error(:disabling_failed, 'Account was not disabled', result.errors),
                 status: 422
        end
      end

      def enable
        result = Accounts::Enable.run(account: @account)
        if result.valid?
          render :show, status: :ok
        else
          render json: standard_error(:disabling_failed, 'Account was not disabled', result.errors),
                 status: 422
        end
      end

      private

      def account_params
        permitted_params =
          params.require(:account).permit(
            :enabled, :staff_id, :title, :whitelabel, :agency_id, contact_info: {},
                                                                  settings: {}, addresses_attributes: %i[
                                                                    city country county id latitude longitude
                                                                    plus_four state street_name street_number
                                                                    street_two timezone zip_code
                                                                  ]
          )
        existed_ids = permitted_params[:addresses_attributes]&.map { |addr| addr[:id] }

        unless existed_ids.nil? || existed_ids.compact.blank?
          (@account.addresses.pluck(:id) - existed_ids).each do |id|
            permitted_params[:addresses_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end

        permitted_params
      end

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
          title: %i[scalar like],
          created_at: %i[scalar array interval],
          updated_at: %i[scalar array interval],
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
