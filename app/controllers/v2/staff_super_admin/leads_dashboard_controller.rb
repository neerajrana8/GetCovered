module V2
  module StaffSuperAdmin
    class LeadsDashboardController < StaffSuperAdminController

      def index
        leads = Lead.actual.presented
        date_slug_format = '%Y-%m-%d'
        date_utc_format = '%Y-%m-%d %H:%M:%S'
        date_from = DateTime.now - 7.days
        date_to = DateTime.now
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
          date_from = Time.zone.parse(filter[:last_visit][:start]) unless filter[:last_visit][:start].nil?
          date_to = Time.zone.parse(filter[:last_visit][:end]) unless filter[:last_visit][:end].nil?
          leads = leads.archived unless filter[:archived].nil?
          leads = leads.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?
          leads = leads.by_account(filter[:account_id]) unless filter[:account_id].nil?
          leads = leads.by_branding_profile(filter[:branding_profile_id]) unless filter[:branding_profile_id].nil?
        end

        # TODO: add beginning_of_the_day after recent_leads action fixed
        date_from = date_from.utc.strftime(date_utc_format)
        date_to = date_to.utc.end_of_day.strftime(date_utc_format)

        leads = leads.by_last_visit(date_from, date_to)
        leads_cx = leads.not_converted.count

        lead_events = LeadEvent.by_created_at(date_from, date_to)
        lead_events = lead_events.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?

        leads_filtered = []

        # Policy Type filter
        if filter[:lead_events].present?

          lead_data = Lead.select(:id).distinct(:id).presented.not_converted
                        .includes(:account, :agency, :branding_profile, :lead_events).preload(:lead_events)
          lead_data = lead_data
                        .where(
                          lead_events: { policy_type_id: filter[:lead_events][:policy_type_id] },
                          last_visit: date_from..date_to,
                          archived: false
                        )
          lead_data = lead_data.where(agency: filter[:agency_id]) unless filter[:agency_id].nil?
          lead_data = lead_data.where(account_id: filter[:account_id]) unless filter[:account_id].nil?
          lead_data = lead_data.where(branding_profile_id: filter[:branding_profile_id]) unless filter[:branding_profile_id].nil?

          lead_data_cx = lead_data.count
          leads_cx = lead_data_cx
          leads_filtered = lead_data.pluck(:lead_id)
          leads = leads.where(id: leads_filtered) unless leads_filtered.count.zero?

          lead_events = LeadEvent.where(lead_id: leads_filtered)
        end

        lead_events_total = lead_events.count

        total_by_status = Lead.get_stats(
          date_from,
          date_to,
          filter[:agency_id],
          filter[:branding_profile_id],
          filter[:account_id],
          leads_filtered
        )

        unless total_by_status.nil?

          total_by_status_grouped = leads.grouped_by_last_visit
          lead_events_grouped = lead_events.grouped_by_created_at

          @stats = {
            leads: leads_cx,
            site_visits: lead_events_total,
            customers: total_by_status['converted'],
            applications: total_by_status['applications'],
            not_finished_applications: total_by_status['not_finished_applications'],
            visitors: total_by_status['prospected'] + total_by_status['not_converted'],
            conversions: total_by_status['converted']
          }

          total_by_status_grouped.each do |s|
            date_slug = s.last_visit.strftime(date_slug_format)
            @stats_by[date_slug] = {
              leads: s.not_converted,
              customers: s.converted,
              applications: s.applications,
              not_finished_applications: s.not_finished_applications,
              conversions: s.converted,
              visitors: s.prospected + s.not_converted
            }
          end

          lead_events_grouped.each do |e|
            date_slug = e.created_at.strftime(date_slug_format)
            @stats_by[date_slug] ||= {}
            @stats_by[date_slug][:site_visits] = e.cx
          end

        end

        render 'v2/shared/leads/dashboard_index'
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
