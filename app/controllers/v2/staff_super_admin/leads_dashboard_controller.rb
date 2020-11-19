module V2
  module StaffSuperAdmin
    class LeadsDashboardController < StaffSuperAdminController

      def index
        super(:@leads, Lead, :profile, :tracking_url)
        @stats = {site_visits: site_visits, leads: leads, applications: applications,
                  not_finished_applications: not_finished_applications, conversions: conversions}
        @stats_by = {}

        start_date = Date.parse(date_params[:start])
        end_date   = Date.parse(date_params[:end])

        if filter_by_day?(start_date, end_date)
          start_date.upto(end_date) do |date|
            params[:filter][:last_visit] = Date.parse("#{date}").all_day
            super(:@leads, Lead, :profile, :tracking_url)
            @stats_by["#{date}"] = {site_visits: site_visits, leads: leads, applications: applications,
                                    not_finished_applications: not_finished_applications, conversions: conversions}
          end
        else
          while start_date < end_date
            params[:filter][:last_visit] = Date.parse("#{start_date}").all_month
            super(:@leads, Lead, :profile, :tracking_url)
            @stats_by["#{start_date.end_of_month}"] = {site_visits: site_visits, leads: leads, applications: applications,
                                                       not_finished_applications: not_finished_applications, conversions: conversions}
            start_date += 1.month
          end
        end
        render 'v2/shared/leads/dashboard_index'
      end

      def get_filters
        render json: {campaign_source: TrackingUrl.not_deleted.pluck(:campaign_source).uniq.as_json,
                      campaign_name: TrackingUrl.not_deleted.pluck(:campaign_name).uniq.as_json,
                      campaign_medium: TrackingUrl.not_deleted.pluck(:campaign_medium).uniq.as_json}
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            agency_id: [:scalar],
            last_visit: [:interval, :scalar],
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

      #need to add validation
      def date_params
        if params[:filter].present?
          {
              start: params[:filter][:last_visit][:start],
              end: params[:filter][:last_visit][:end]
          }
        else
          params["filter"] = {}
          {
              start: Lead.date_of_first_lead.to_s || Time.now.beginning_of_year,
              end: Time.now.to_s
          }
        end
      end

      private

      def filter_by_day?(start_date, end_date)
        (((end_date - 1.month) == start_date ) || ((end_date - 1.week) == start_date ))
      end

      #data for last_month or last_year of from the begining of the year
      def filter_by_month?(start_date, end_date)
         ((end_date - 1.year) == start_date) || (start_date == end_date.beginning_of_year) || (end_date.mjd - start_date.mjd > 31)
      end

      #need to refactor
      def site_visits
        visits = 0
        @leads.each do |lead|
          visits+=lead.lead_events.order("DATE(created_at)").group("DATE(created_at)").count.keys.size
        end
        visits
      end

      def leads
        @leads.count
      end

      def applications
        @leads.where.not(user_id: nil).where(status: ["prospect","converted"]).count
      end

      def not_finished_applications
        @leads.where.not(user_id: nil).where(status: ["prospect"]).count
      end

      def conversions
        @leads.where(status: 'converted').count
      end

    end
  end
end
