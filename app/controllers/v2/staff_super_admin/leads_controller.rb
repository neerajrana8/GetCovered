module V2
  module StaffSuperAdmin
    class LeadsController < StaffSuperAdminController
      include ActionController::MimeResponds
      include Leads::LeadsRecentMethods

      before_action :set_lead, only: %i[update show]
      before_action :set_substrate, only: :index

      def index
        filter = params[:filter]

        date_utc_format = '%Y-%m-%d %H:%M:%S'

        date_from_dt = DateTime.now - 1.month
        date_to_dt = DateTime.now

        if filter[:last_visit]
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
        params[:pagination][:page] += 1
        params[:pagination][:per] = 20 if params[:pagination][:per].zero?

        @leads = leads.page(params[:pagination][:page]).per(params[:pagination][:per])

        # TODO: Deprecate headers pagination unless client side support fixed
        response.headers['total-pages'] = @leads.total_pages
        response.headers['current-page'] = @leads.current_page
        response.headers['total-entries'] = leads.count

        # TODO: Copied from old code, needs to be moved to separate endpoint
        if need_to_download?
          ::Leads::RecentLeadsReportJob.perform_later(@leads.pluck(:id), params.as_json, current_staff.email)
          render json: { message: 'Report were sent' }, status: :ok
        else
          render 'v2/shared/leads/index'
        end
      end

      def show
        @visits = @lead.lead_events.order('DATE(created_at)').group('DATE(created_at)').count.keys.size
        @last_premium_estimation =
          @lead.lead_events.where("(data -> 'total_amount') is not null").order(created_at: :desc).first
        render 'v2/shared/leads/show'
      end

      def update
        if update_allowed?
          if @lead.update_as(current_staff, update_params)
            render 'v2/shared/leads/show', status: :ok
          else
            render json: @lead.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: [I18n.t('user_users_controler.unauthorized_access')] },
                 status: :unauthorized
        end
      end

      private

      def set_lead
        @lead = access_model(::Lead, params[:id])
      end

      def update_params
        return({}) if params[:lead].blank?

        params.require(:lead).permit(:archived)
      end

      def set_substrate
        if @substrate.nil?
          @substrate = access_model(::Lead).presented.not_converted.includes(:profile, :tracking_url).preload(:lead_events)
          # need to delete after fix on ui
          # if params[:filter].present? && params[:filter][:archived]
          #  @substrate = access_model(::Lead).presented.not_converted.archived.includes(:profile, :tracking_url)
          # elsif params[:filter].nil? || !!params[:filter][:archived]
          #  @substrate = access_model(::Lead).presented.not_converted.not_archived.includes(:profile, :tracking_url)
          # end
        end
      end

      def update_allowed?
        true
      end

    end
  end
end
