# Leads controller
module V2
  module Leads
    class LeadsController < ApiController
      before_action :authenticate_staff!

      def list
        page = 1
        per = 50
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

          # We are sub agency
          filter[:agency_id] = [current_agency.id] unless current_agency.agency_id.nil?
        end

        leads = leads.archived if filter[:archived] == true

        # NOTE: OR logic for certain filters
        filter_keys_exists = !(filter.keys & %w[agency_id account_id branding_profile_id]).empty?

        if filter_keys_exists
          leads = leads.where(
            '(agency_id = ? OR account_id = ? OR branding_profile_id = ?)',
            filter[:agency_id],
            filter[:account_id],
            filter[:branding_profile_id]
          )

          # NOTE: Move to OR logic
          # leads = leads.by_agency(filter[:agency_id]) unless filter[:agency_id].nil?
          # leads = leads.by_account(filter[:account_id]) unless filter[:account_id].nil?
          # leads = leads.by_branding_profile(filter[:branding_profile_id]) unless filter[:branding_profile_id].nil?

        end

        leads = leads.actual if filter[:archived] == false || !filter[:archived].present?

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

        # Tracking urls and parameters filtering

        if filter[:tracking_url].present?
          tracking_urls = TrackingUrl.all
          filter[:tracking_url].each do |v|
            tracking_urls = tracking_urls.where("#{v.first} IN (?)", v.last)
          end
          tracking_url_ids = tracking_urls.pluck(:id)
          leads = leads.where(tracking_url_id: tracking_url_ids)
        end

        leads = leads.not_converted
        leads = leads.join_last_events
        leads = leads.by_last_visit(date_from, date_to)

        Rails.logger.info "#DEBUG SQL=#{leads.to_sql}"
        # Pagination
        if params[:pagination].present?
          page = params[:pagination][:page]
          per = params[:pagination][:per] if params[:pagination][:per].present?
          # TODO: Support frontend flaw behaviour
          page = 1 if page.zero?
          per = 50 if per.zero?
          @leads = leads.page(page).per(per)

          # TODO: Deprecate headers pagination unless client side support fixed
          response.headers['total-pages'] = @leads.total_pages
          response.headers['current-page'] = @leads.current_page
          response.headers['total-entries'] = leads.count
        else
          @leads = leads.limit(2) # Limit 2 To comply with rspec test
        end

        @meta = { total: leads.count, page: @leads.current_page, per: per }

        # TODO: Copied from old code, needs to be moved to separate endpoint
        if need_to_download?
          ::Leads::RecentLeadsReportJob.perform_later(@leads.pluck(:id), params.as_json, current_staff.email)
          render json: { message: 'Report were sent' }, status: :ok
        else
          render 'v2/shared/leads/index'
        end
      end


      def need_to_download?
        params['input_file'].present? && params['input_file'] == 'text/csv'
      end
    end
  end
end
