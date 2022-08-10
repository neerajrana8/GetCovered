module V2
  module StaffSuperAdmin
    class LeadsDashboardController < StaffSuperAdminController
      # include Leads::LeadsDashboardMethods

      CACHE_KEY = 'dashboards'.freeze
      CACHE_EXPIRE = 5 # In minutes

      before_action :set_substrate, only: :index

      def set_substrate
        @substrate = access_model(::Lead).presented.not_converted.includes(:profile, :tracking_url).preload(:lead_events)
      end

      def generate_cache_key(payload)
        token = []
        token << CACHE_KEY
        payload.each do |v|
          token << v.map { |k| k }
        end
        cache_key = token.join('_')
        cache_key
      end

      def index
        filter = {}
        filter = params[:filter] if params[:filter].present?

        cache_key = generate_cache_key(filter)

        stats = Rails.cache.read(cache_key)

        if stats.nil?
          leads = Lead.actual.presented
          date_slug_format = '%Y-%m-%d'
          date_utc_format = '%Y-%m-%d %H:%M:%S'
          trunc_by = 'day'
          date_from_dt = DateTime.now - 7.days
          date_to_dt = DateTime.now

          stats = {
            leads: 0,
            site_visits: 0,
            customers: 0,
            applications: 0,
            not_finished_applications: 0,
            visitors: 0,
            conversions: 0
          }
          stats_empty = stats.clone
          stats_by = {}

          # Role attributes filters

          if current_staff.role == 'staff' && !current_staff.getcovered_agent?
            if current_staff.organizable_type == 'Account'
              filter[:account_id] = [current_staff.organizable.id]
              leads = leads.where(account_id: current_staff.organizable.id)
            end
          end

          date_from_dt = Time.zone.parse(filter[:last_visit][:start]) unless filter[:last_visit][:start].nil?
          date_to_dt = Time.zone.parse(filter[:last_visit][:end]) unless filter[:last_visit][:end].nil?
          # Date diff in months
          date_diff = ((date_to_dt.utc - date_from_dt.utc.end_of_day).to_i / 60 / 60 / 24 / 30).round

          # Group charts data by months if date_from date_to diff more than 2 months
          if date_diff >= 2
            date_slug_format = '%Y-%m'
            trunc_by = 'month'
          end

          # TODO: add beginning_of_the_day after recent_leads action fixed
          date_from = date_from_dt.utc.strftime(date_utc_format)
          date_to = date_to_dt.end_of_day.utc.strftime(date_utc_format)

          # Interface filters
          if filter
            leads = leads.archived unless filter[:archived].nil?
            leads = leads.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?
            leads = leads.by_account(filter[:account_id]) unless filter[:account_id].nil?
            leads = leads.by_branding_profile(filter[:branding_profile_id]) unless filter[:branding_profile_id].nil?

            # Tracking urls and parameters filtering
            tracking_urls = TrackingUrl.all
            if filter[:tracking_url].present?
              filter[:tracking_url].each do |v|
                tracking_urls = tracking_urls.where("#{v.first} IN (?)", v.last)
              end
              tracking_url_ids = tracking_urls.pluck(:id)
              leads = leads.where(tracking_url_id: tracking_url_ids)
            end

            if filter[:lead_events].present?

              leads_by_policy_type =
                Lead.select(:id).distinct(:id).presented.not_converted
                  .includes(:account, :agency, :branding_profile, :lead_events).preload(:lead_events)
                  .where(
                    lead_events: { policy_type_id: filter[:lead_events][:policy_type_id] },
                    last_visit: date_from..date_to,
                    archived: false
                  )

              leads = leads.where(id: leads_by_policy_type.pluck(:lead_id))

            end
          end

          leads = leads.by_last_visit(date_from, date_to)
          leads_cx = leads.not_converted.count
          leads_ids = leads.pluck(:id)

          lead_events_total = leads.sum(:lead_events_cx)

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
            stats_by[date_slug] = stats_empty
          end

          unless total_by_status.nil?

            total_by_status_grouped = leads.grouped_by_date(trunc_by)

            stats = {
              leads: leads_cx,
              site_visits: lead_events_total,
              customers: total_by_status['converted'],
              applications: total_by_status['applications'],
              not_finished_applications: total_by_status['not_finished_applications'],
              visitors: total_by_status['converted'] + total_by_status['not_converted'],
              conversions: total_by_status['converted']
            }

            total_by_status_grouped.each do |s|
              date_slug = s.last_visit.strftime(date_slug_format)
              site_visits = s.site_visitors
              site_visits = 0 if s.site_visitors.nil?
              stats_by[date_slug] = {
                leads: s.not_converted,
                customers: s.converted,
                applications: s.applications,
                not_finished_applications: s.not_finished_applications,
                conversions: s.converted,
                visitors: s.converted + s.not_converted,
                site_visits: site_visits
              }
            end

            # Sort hash by date keys for charts
            stats_by = stats_by.sort.to_h
          end
          stats[:stats_by] = stats_by
          Rails.cache.write(cache_key, stats, expires_in: CACHE_EXPIRE.minute)
        end
        render json: stats
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
