module V2
  module StaffAgency
    class LeadsController < StaffAgencyController

      before_action :set_substrate, only: :index

      def index
        super(:@leads, @substrate)
        render 'v2/shared/leads/index'
      end

      def show
        @lead = access_model(::Lead, params[:id])
        render 'v2/shared/leads/show'
      end

      private

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Lead).includes(:profile, :tracking_url).presented
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            created_at: [:scalar, :array, :interval],
            email: [:scalar, :like],
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
