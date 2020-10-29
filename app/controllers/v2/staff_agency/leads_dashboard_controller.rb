module V2
  module StaffAgency
    class LeadsDashboardController < StaffAgencyController

      before_action :set_substrate, only: :index
      
      def index
        super(:@leads, @substrate, :profile, :tracking_url)
        @stats = {site_visits: site_visits, leads: leads, applications: applications, conversions: conversions}
        @stats_by = {date: "", stats: {site_visits: site_visits, leads: leads, applications: applications, conversions: conversions}}
        render 'v2/shared/leads/dashboard_index'
        #render json: {site_visits: site_visits, leads: leads, applications: applications, conversions: conversions}
        #render 'v2/shared/leads/index'
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            agency_id: [:scalar],
            last_visit: [:interval],
            tracking_url: {
                campaign_source: [:scalar],
                campaign_medium: [:scalar],
                campaign_name: [:scalar]
            }
        }
      end

      def supported_orders
        supported_filters(true)
      end

      #need to add default params for filtering & ordering
      def lead_params
        params.permit(:filter, :sort)
      end

      def date_params
        params[:filter]
      end

      private

      def stats_by(date_value)


      end

      #need to refactor
      def site_visits
        visits = 0
        @leads.each do |lead|
          visits+=lead.lead_events.order("DATE(created_at)").group("DATE(created_at)").count.keys.size
          #visits+=lead.lead_events.count
        end
        visits
      end

      def leads
        @leads.count
      end

      def applications
        @leads.where.not(user_id: nil, status: 'converted').count
      end

      def conversions
        @leads.where(status: 'converted').count
      end

      private

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Lead).includes(:profile, :tracking_url)
        end
      end
    end
  end
end
