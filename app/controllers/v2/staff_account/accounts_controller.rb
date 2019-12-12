##
# V2 StaffAccount Accounts Controller
# File: app/controllers/v2/staff_account/accounts_controller.rb

module V2
  module StaffAccount
    class AccountsController < StaffAccountController

      before_action :set_account, only: [:update, :show]

      def show
        render :show, status: :ok
      end

      def update
        if update_allowed?
          if @account.update(update_params)
            render :show,
                   status: :ok
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
        super + "/accounts"
      end

      def update_allowed?
        true
      end

      def set_account
        @account = current_staff.organizable
      end

      def update_params
        return({}) if params[:account].blank?
        params.require(:account).permit(
          :title, :tos_accepted, contact_info: {}, settings: {},
          addresses_attributes: [
            :city, :country, :county, :id, :latitude, :longitude,
            :plus_four, :state, :street_name, :street_number,
            :street_two, :timezone, :zip_code
          ]
        )
      end

    end
  end
end
