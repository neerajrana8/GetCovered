module V2
  module StaffSuperAdmin
    class TrackingUrlsController < StaffSuperAdminController
      before_action :set_tracking_url, only: :show

      before_action :set_substrate, only: :index


      def show
        render 'v2/shared/tracking_urls/show'
      end

      def index
        super(:@tracking_urls, @substrate)
        render 'v2/shared/tracking_urls/index'
      end

      private

      def set_tracking_url
        @tracking_url = TrackingUrl.not_deleted.find(params[:id])
      end

      def create_params
        return({}) if params[:tracking_url].blank?

        to_return = params.require(:tracking_url).permit(
            :landing_page, :campaign_source, :campaign_medium,
            :campaign_name, :campaign_term, :campaign_content
        )
        to_return
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = TrackingUrl.not_deleted
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            agency_id: %i[scalar array]
        }
      end
    end
  end
end
