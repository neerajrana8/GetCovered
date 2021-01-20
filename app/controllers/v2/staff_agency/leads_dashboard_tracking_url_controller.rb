module V2
  module StaffAgency
    class LeadsDashboardTrackingUrlController < StaffAgencyController
      before_action :set_substrate, only: :index

      def index
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
            },
            deleted: [:scalar]
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def set_substrate
        super
        #need to delete after fix on ui
        if @substrate.nil?
          @substrate = access_model(::TrackingUrl)
          params[:filter][:deleted] = params[:filter][:archived] if params[:filter].present? && params[:filter][:archived].present?
          params[:filter].delete(:archived)
          params[:campaign_source] = unescape_param(params[:campaign_source])
          params[:campaign_medium] = unescape_param(params[:campaign_medium])
          params[:campaign_name] = unescape_param(params[:campaign_name])
          params[:campaign_term] = unescape_param(params[:campaign_term])
          params[:campaign_content] = unescape_param(params[:campaign_content])
          #if params[:filter].present? && params[:filter][:archived]
          #  @substrate = access_model(::TrackingUrl).deleted
          #elsif params[:filter].nil? || !!params[:filter][:archived]
          #  @substrate = access_model(::TrackingUrl).not_deleted
          #end
        end
      end

      def escape_param(value)
        CGI::escape(value)
      end

      def unescape_param(value)
        CGI::unescape(value)
      end

    end
  end
end
