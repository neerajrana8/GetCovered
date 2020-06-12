##
# V2 StaffAccount Accounts Controller
# File: app/controllers/v2/staff_account/accounts_controller.rb

module V2
  module StaffAccount
    class AccountsController < StaffAccountController
      before_action :set_account, only: %i[update show]

      def account_policies
        account = Account.includes(:policies).find(params[:id])
        @account_policies = paginator(account.policies)
        render '/v2/staff_account/accounts/account_policies', status: :ok
      end

      def account_communities
        account = Account.includes(:insurables).find(params[:id])
        @account_communities = paginator(Insurable.where(account_id: account.id).communities)
        render '/v2/staff_account/accounts/account_communities', status: :ok
      end

      def account_buildings
        account = Account.includes(:insurables).find(params[:id])
        @account_buildings = paginator(Insurable.where(account_id: account.id).buildings)
        render '/v2/staff_account/accounts/account_buildings', status: :ok
      end

      def account_units
        account = Account.includes(:insurables).find(params[:id])
        @account_units = paginator(Insurable.where(account_id: account.id).units)
        render '/v2/staff_account/accounts/account_units', status: :ok
      end

      def show
        render :show, status: :ok
      end

      def update
        if update_allowed?
          if @account.update_as(current_staff, update_params)
            render :show, status: :ok
          else
            render json: @account.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      private

      def view_path
        super + '/accounts'
      end

      def update_allowed?
        true
      end

      def set_account
        @account = current_staff.organizable
      end

      def update_params
        return({}) if params[:account].blank?

        permitted_params =
          params.require(:account).permit(
            :title, :tos_accepted, contact_info: {}, settings: {},
                                   addresses_attributes: %i[
                                     city country county id latitude longitude
                                     plus_four state street_name street_number
                                     street_two timezone zip_code
                                   ]
          )

        existed_ids = permitted_params[:addresses_attributes]&.map { |addr| addr[:id] }

        unless existed_ids.nil?
          (@account.addresses.pluck(:id) - existed_ids).each do |id|
            permitted_params[:addresses_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end

        permitted_params
      end
    end
  end
end
