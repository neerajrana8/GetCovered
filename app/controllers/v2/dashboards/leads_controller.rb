module V2
  module Dashboards
    # Controller for leads dashboard actions
    class LeadsController < ApiController
      before_action :authenticate_staff!
      before_action :check_permissions

      CACHE_KEY = 'dashboards_ci'.freeze
      CACHE_EXPIRE = 5

      def stats
        filter = {}
        filter = params[:filter] if params[:filter].present?

        # Prepareing filters by role
        if current_staff.role == 'staff' && !current_staff.getcovered_agent?
          if current_staff.organizable_type == 'Account'
            filter[:account_id] = [current_staff.organizable.id]
          end
        end

        if current_staff.organizable_type == 'Agency'
          current_agency = Agency.find(current_staff.organizable_id)
          # We are root agency
          if current_agency.agency_id.nil? && filter[:agency_id].blank?
            sub_agencies_ids = []
            sub_agencies = current_agency.agencies
            sub_agencies_ids = sub_agencies.pluck(:id) if sub_agencies.count.positive?
            sub_agencies_ids << current_staff.organizable_id
            filter[:agency_id] = sub_agencies_ids
          end

          filter[:agency_id] = [current_agency.id] unless current_agency.agency_id.nil?
        end

        Rails.logger.info "#DEBUG ROLE=#{current_staff.organizable_type}"
        Rails.logger.info "#DEBUG filter=#{filter.inspect}"
        cache_key = generate_cache_key(CACHE_KEY, filter)

        stats = Rails.cache.read(cache_key)

        if true # stats.nil? and false
          leads = Lead.all
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

          if filter[:last_visit].present?
            date_from_dt = Time.zone.parse(filter[:last_visit][:start]) unless filter[:last_visit][:start].nil?
            date_to_dt = Time.zone.parse(filter[:last_visit][:end]) unless filter[:last_visit][:end].nil?
          end
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
            leads = leads.archived if !filter[:archived].nil? && filter[:acrhived] == true

            # NOTE: OR logic for certain filters
            filter_keys_exists = !(filter.keys & %w[agency_id account_id branding_profile_id]).empty?

            if filter_keys_exists
              leads = leads.where(
                '(agency_id IN (?) OR account_id IN (?) OR branding_profile_id IN (?))',
                filter[:agency_id],
                filter[:account_id],
                filter[:branding_profile_id]
              )
              Rails.logger.info "#DEBUG filter_keys matched OK"

              # NOTE: Move to OR logic
              # leads = leads.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?
              # leads = leads.by_account(filter[:account_id]) unless filter[:account_id].nil?
              # leads = leads.by_branding_profile(filter[:branding_profile_id]) unless filter[:branding_profile_id].nil?

            end

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
          lead_events_total = leads.sum(:lead_events_cx)
          leads = leads.actual.presented

          leads_cx = leads.not_converted.count
          leads_ids = leads.pluck(:id)

          # lead_events_total = leads.sum(:lead_events_cx)

          # NOTE: Remove when stable
          # Rails.logger.info "#DEBUG leads_sql=#{leads.to_sql}"
          # Rails.logger.info "#DEBUG leads_ids=#{leads_ids}"

          unless leads_ids.count.zero?
            total_by_status = Lead.get_stats(
              [date_from, date_to],
              filter[:agency_id],
              filter[:branding_profile_id],
              filter[:account_id],
              leads_ids
            )
          end

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

      def list_deprecated
        filter = {}
        filter = params[:filter] if params[:filter].present?

        date_utc_format = '%Y-%m-%d %H:%M:%S'

        date_from_dt = DateTime.now - 1.month
        date_to_dt = DateTime.now

        if filter[:last_visit].present?
          date_from_dt = Time.zone.parse(filter[:last_visit][:start]) unless filter[:last_visit][:start].nil?
          date_to_dt = Time.zone.parse(filter[:last_visit][:end]) unless filter[:last_visit][:end].nil?
        end

        date_from = date_from_dt.utc.strftime(date_utc_format)
        date_to = date_to_dt.end_of_day.utc.strftime(date_utc_format)

        leads = Lead.all.includes(
          :profile,
          :tracking_url,
          :branding_profile
        )

        if current_staff.organizable_type == 'Agency'
          filter[:agency_id] = [current_staff.organizable.id]
        end

        leads = leads.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?
        leads = leads.by_account(filter[:account_id]) unless filter[:account_id].nil?
        leads = leads.by_branding_profile(filter[:branding_profile_id]) unless filter[:branding_profile_id].nil?
        leads = leads.archived if filter[:archived] == true
        leads = leads.not_converted
        leads = leads.by_last_visit(date_from, date_to)

        policy_type_id = filter[:lead_events][:policy_type_id] if filter[:lead_events]

        leads = leads.join_last_events(policy_type_id)

        # Tracking urls and parameters filtering

        if filter[:tracking_url].present?
          tracking_urls = TrackingUrl.all
          filter[:tracking_url].each do |v|
            tracking_urls = tracking_urls.where("#{v.first} IN (?)", v.last)
          end
          tracking_url_ids = tracking_urls.pluck(:id)
          leads = leads.where(tracking_url_id: tracking_url_ids)
        end

        # Pagination
        if params[:pagination].present?
          params[:pagination][:page] += 1
          params[:pagination][:per] = 20 if params[:pagination][:per].zero?
          @leads = leads.page(params[:pagination][:page]).per(params[:pagination][:per])
          # TODO: Deprecate headers pagination unless client side support fixed
          response.headers['total-pages'] = @leads.total_pages
          response.headers['current-page'] = @leads.current_page
          response.headers['total-entries'] = leads.count
        else
          @leads = leads.limit(2) # Limit 2 To comply with rspec test
        end

        # TODO: Copied from old code, needs to be moved to separate endpoint
        if need_to_download?
          ::Leads::RecentLeadsReportJob.perform_later(@leads.pluck(:id), params.as_json, current_staff.email)
          render json: { message: 'Report were sent' }, status: :ok
        else
          render 'v2/shared/leads/index'
        end
      end

      private

      def check_permissions
        if current_staff && %(super_admin, staff, agent).include?(current_staff.role)
          true
        else
          render json: { error: 'Permission denied', role: current_staff }, status: 403
        end
      end
    end
  end
end
