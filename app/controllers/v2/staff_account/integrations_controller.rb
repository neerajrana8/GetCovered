module V2
  module StaffAccount
    class IntegrationsController < StaffAccountController
      before_action :set_substrate, only: :index
      before_action :set_integration, only: %i[update show]

      def show
        render json: { no: "way" },
          status: 200
      end

      def update
      end

      private

      def update_params
        return({}) if params[:lead].blank?

      end

      def set_substrate
        #@substrate = access_model(::Integration)
      end

      def supported_orders
        supported_filters(true)
      end

      def update_allowed?
        true
      end

    end
  end
end
