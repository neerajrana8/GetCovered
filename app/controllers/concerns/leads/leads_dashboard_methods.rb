module Leads
  module LeadsDashboardMethods
    extend ActiveSupport::Concern

    def index
      leads = Lead.actual.presented
      date_slug_format = '%Y-%m-%d'
      date_utc_format = '%Y-%m-%d %H:%M:%S'
      trunc_by = 'day'
      date_from_dt = DateTime.now - 7.days
      date_to_dt = DateTime.now
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

      filter = params[:filter] if params[:filter].present?

      # Role attributes filters
      if current_staff.role == 'staff' && !current_staff.getcovered_agent?
        if current_staff.organizable_type == 'Account'
          filter[:account_id] = [current_staff.organizable.id]
          leads = leads.where(account_id: current_staff.organizable.id)
        end
      end

      # Interface filters
      if filter
        date_from_dt = Time.zone.parse(filter[:last_visit][:start]) unless filter[:last_visit][:start].nil?
        date_to_dt = Time.zone.parse(filter[:last_visit][:end]) unless filter[:last_visit][:end].nil?
        leads = leads.archived unless filter[:archived].nil?
        leads = leads.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?
        leads = leads.by_account(filter[:account_id]) unless filter[:account_id].nil?
        leads = leads.by_branding_profile(filter[:branding_profile_id]) unless filter[:branding_profile_id].nil?

        # Tracking urls and parameters filtering
        tracking_urls = TrackingUrl.all
        if filter[:tracking_url].present?
          filter[:tracking_url].each do |v|
            tracking_urls = tracking_urls.where("#{v.first} IN (?)", v.last.join(','))
          end
          Rails.logger.info "#DEBUG #{tracking_urls.to_sql}"
          tracking_url_ids = tracking_urls.pluck(:id)
          leads = leads.where(tracking_url_id: tracking_url_ids)
        end

        if filter[:lead_events].present?
          leads = leads.includes(:lead_events)
                    .where(lead_events: { policy_type_id: filter[:lead_events][:policy_type_id] })
        end
      end

      # Date diff in months
      date_diff = ((date_to_dt.utc - date_from_dt.utc.end_of_day).to_i / 60 / 60 / 24 / 30).round

      # Group charts data by months if date_from date_to diff more than 2 months
      if date_diff >= 2
        date_slug_format = '%Y-%m-01'
        trunc_by = 'month'
      end

      # TODO: add beginning_of_the_day after recent_leads action fixed
      date_from = date_from_dt.utc.strftime(date_utc_format)
      date_to = date_to_dt.end_of_day.utc.strftime(date_utc_format)

      leads = leads.by_last_visit(date_from, date_to)
      leads_cx = leads.not_converted.count
      leads_ids = leads.pluck(:id)

      lead_events_total = 0
      lead_events = LeadEvent.where(lead_id: leads_ids) unless leads_ids.count.zero?
      lead_events_total = lead_events.count unless lead_events.blank?

      total_by_status = Lead.get_stats(
        [date_from, date_to],
        filter[:agency_id],
        filter[:branding_profile_id],
        filter[:account_id],
        leads_ids
      )

      # Prepare charts data

      date_from_dt.to_date.upto(date_to_dt.to_date).each do |date|
        date_slug = date.strftime(date_slug_format)
        @stats_by[date_slug] = @stats
      end

      unless total_by_status.nil?

        total_by_status_grouped = leads.grouped_by_last_visit(trunc_by)
        lead_events_grouped = lead_events.grouped_by_created_at(trunc_by) unless lead_events.blank?

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

        if lead_events.present?
          lead_events_grouped.each do |e|
            date_slug = e.created_at.strftime(date_slug_format)
            @stats_by[date_slug] ||= {}
            @stats_by[date_slug][:site_visits] = e.cx
          end
        end

        # Sort hash by date keys
        @stats_by = @stats_by.sort.to_h
      end

      render 'v2/shared/leads/dashboard_index'
    end
  end
end
