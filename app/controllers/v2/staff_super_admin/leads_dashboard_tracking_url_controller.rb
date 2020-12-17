module V2
  module StaffSuperAdmin
    class LeadsDashboardTrackingUrlController < StaffSuperAdminController

      def index
        super(:@tracking_urls, TrackingUrl, :leads)
        @tracking_url_counts = {}
        calculate_counts
        render 'v2/shared/tracking_urls/index'
      end

      private

      def calculate_counts
        @tracking_urls.each do |tr_url|
          lead_events_count = 0
          tr_url.leads.each{|el| lead_events_count+=el.lead_events.count}
          @tracking_url_counts[tr_url.id] = { leads_count: tr_url.leads.count, lead_events_count: lead_events_count }
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

    end
  end
end
