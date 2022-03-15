##
# V2 Public Communities Controller
# File: app/controllers/v2/public/addresses_controller.rb

module V2
  module StaffSuperAdmin
    class CommunitiesController < StaffSuperAdminController
      def index
        if params[:search].presence && params[:account_id].presence
          account = Account.find(params[:account_id])
          @insurables = Insurable.where(account_id: account.id).communities.where(
            "title ILIKE '%#{ params[:search] }%'"
          )

          @response = V2::StaffSuperAdmin::Insurables.new(
            @insurables
          ).response

          render json: @response.to_json,
                 status: :ok
        else
          render json: [].to_json,
                 status: :ok
        end
      end
    end
  end
end
