module V2
  module StaffAgency
    class LeadsController < StaffAgencyController

      before_action :set_substrate, only: :index
      before_action :set_lead, only: [:update, :show]

      def index
        super(:@leads, @substrate)
        if need_to_download?
          ::Leads::RecentLeadsReportJob.perform_later(@leads.pluck(:id), params.as_json, current_staff.email)
          render json: { message: 'Report were sent' }, status: :ok
        else
          render 'v2/shared/leads/index'
        end
      end

      def show
        @visits = @lead.lead_events.order("DATE(created_at)").group("DATE(created_at)").count.keys.size
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
          @substrate = access_model(::Lead).presented.not_converted.includes(:profile, :tracking_url)
          #need to delete after fix on ui
          #if params[:filter].present? && params[:filter][:archived]
          #   @substrate = access_model(::Lead).presented.not_converted.archived.includes(:profile, :tracking_url)
          # elsif params[:filter].nil? || !!params[:filter][:archived]
          #  @substrate = access_model(::Lead).presented.not_converted.not_archived.includes(:profile, :tracking_url)
          #end
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            created_at: [:scalar, :array, :interval],
            email: [:scalar, :like],
            agency_id: [:scalar, :interval],
            status: [:scalar],
            archived: [:scalar]
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def update_allowed?
        true
      end

      #need to add validation
      def date_params
        if params[:filter].present?
          {
              start: params[:filter][:interval][:start],
              end: params[:filter][:interval][:end]
          }
        else
          params[:filter] = {}
          {
              start: Lead.date_of_first_lead.to_s || Time.now.beginning_of_year.to_s,
              end: Time.now.to_s
          }
        end
      end

      def need_to_download?
        params["input_file"].present? && params["input_file"]=="text/csv"
      end

      def file_name
        "recent-leads-#{Date.today}.csv"
      end

    end
  end
end
