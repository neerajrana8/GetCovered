module V2
  module StaffSuperAdmin
    class LeadsController < StaffSuperAdminController

      def index
        super(:@leads, Lead.presented.includes(:profile, :tracking_url).where.not(email: [nil, '']))
        render 'v2/shared/leads/index'
      end

      def show
        @lead = access_model(::Lead, params[:id])
        render 'v2/shared/leads/show'
      end

      private

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            created_at: [:scalar, :array, :interval],
            email: [:scalar, :like],
            agency_id: [:scalar, :interval]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
