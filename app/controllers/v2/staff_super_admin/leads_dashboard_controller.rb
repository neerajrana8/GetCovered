module V2
  module StaffSuperAdmin
    class LeadsDashboardController < StaffSuperAdminController

      def index
        @leads = Lead.actual
        date_slug_format = '%Y-%m-%d'
        date_from = Date.today - 7.days
        date_to = Date.today
        filter = {}

        @stats = {
          leads: 0,
          site_visits: 0,
          customers: 0,
          applications: 0,
          not_finished_applications: 0,
          visitors: 0,
          conversions: 0
        }

        @stats_by = {}

        if params[:filter]
          filter = params[:filter]
          date_from = Date.parse(filter[:last_visit][:start]) unless filter[:last_visit][:start].nil?
          date_to = Date.parse(filter[:last_visit][:end]) unless filter[:last_visit][:start].nil?
          @leads = @leads.archived unless filter[:archived].nil?
          @leads = @leads.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?
        end

        @leads = @leads.by_last_visit(date_from, date_to)
        total_by_status = Lead.get_stats(date_from, date_to, filter[:agency_id])

        unless total_by_status.nil?

          total_by_status_grouped = @leads.grouped_by_last_visit

          lead_events_total = 0
          lead_events_by_date = LeadEvent.by_created_at(date_from.beginning_of_day, date_to.end_of_day)
          lead_events_by_date = lead_events_by_date.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?
          unless lead_events_by_date.nil?
            lead_events_total = lead_events_by_date.count
            lead_events = lead_events_by_date.grouped_by_created_at
          end

          @stats = {
            leads: total_by_status['not_converted'],
            site_visits: total_by_status['visits'],
            customers: total_by_status['converted'],
            applications: total_by_status['applications'],
            not_finished_applications: total_by_status['not_finished_applications'],
            visitors: lead_events_total + total_by_status['not_converted'],
            conversions: total_by_status['converted']
          }

          total_by_status_grouped.each do |s|
            date_slug = s.last_visit.strftime(date_slug_format)
            @stats_by[date_slug] = {
              leads: s.prospected,
              site_visits: s.prospected,
              customers: s.converted,
              applications: s.applications,
              not_finished_applications: s.not_finished_applications,
              conversions: s.converted,
              visitors: s.not_converted
            }
          end

          unless lead_events&.nil?
            lead_events.each do |e|
              date_slug = e.created_at.strftime(date_slug_format)
              @stats_by[date_slug] ||= {}
              @stats_by[date_slug][:visitors] = e.cx
            end
          end

        end

        render 'v2/shared/leads/dashboard_index'
        # render json: {
        #  message: "Currently Unavailable: Under Construction"
        # }, status: :ok
      end

      def get_filters
        data = {}
        %i[campaign_source campaign_name campaign_medium].each do |k|
          data[k] = TrackingUrl.not_deleted.pluck(k).uniq.compact
        end
        render json: data
      end
    end
  end
end
