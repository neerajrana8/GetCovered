module V2
  module StaffAgency
    class LeadsDashboardTrackingUrlController < StaffAgencyController
      before_action :set_substrate, only: :index

      def index
        define_params
        super(:@tracking_urls, @substrate, :leads)
        @tracking_url_counts = {}
        calculate_counts
        render 'v2/shared/tracking_urls/index'
      end

      private

      def calculate_counts
        @tracking_urls.each do |tr_url|
          @tracking_url_counts[tr_url.id] = { leads_count: tr_url.leads.count, converted: tr_url.leads.converted.count }
        end
      end

      def define_params

      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            agency_id: [:scalar],
            campaign_source: [:scalar],
            campaign_medium: [:scalar],
            campaign_name: [:scalar],
            landing_page: [:scalar],
            campaign_term: [:scalar],
            campaign_content: [:scalar],
            leads: {
                last_visit: [:interval, :scalar]
            }
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::TrackingUrl).not_deleted
        end
      end

    end
  end
end
