module DashboardMethods
  extend ActiveSupport::Concern

  included do
    def communities_data
      # index(:@communities_relation, communities, :account, :insurable_data)
      #
      # @communities_data = @communities_relation.map do |community|
      #   {
      #     id: community.id,
      #     title: community.title,
      #     account_title: community.account&.title,
      #     total_units: community.insurable_data&.total_units,
      #     uninsured_units: community.insurable_data&.uninsured_units,
      #     expiring_policies: community.insurable_data&.expiring_policies
      #   }
      # end
      #
      # render template: 'v2/shared/dashboard/communities_data', status: :ok
      render json: {
        message: "Currently Unavailable: Under Construction"
      }, status: :ok
    end

    private

    def supported_filters(called_from_orders = false)
      @calling_supported_orders = called_from_orders
      {
        id: %i[scalar array],
        title: %i[scalar like array],
        permissions: %i[scalar array],
        insurable_type_id: %i[scalar array],
        insurable_id: %i[scalar array],
        agency_id: %i[scalar array],
        account_id: %i[scalar array],
        account: {
          title: %i[scalar like array]
        },
        insurable_data: {
          expiring_policies: %i[scalar array],
          total_units: %i[scalar array],
          uninsured_units: %i[scalar array]
        }
      }
    end

    def supported_orders
      supported_filters(true)
    end
  end
end
