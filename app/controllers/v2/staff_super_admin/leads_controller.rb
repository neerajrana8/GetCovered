module V2
  module StaffSuperAdmin
    class LeadsController < StaffSuperAdminController
      include ActionController::MimeResponds

      before_action :set_lead, only: [:update, :show]
      before_action :set_substrate, only: :index

      def index
        start_date = Date.parse(date_params[:start])
        end_date   = Date.parse(date_params[:end])

        params[:filter][:last_visit] =
          if date_params[:start] == date_params[:end]
            start_date.all_day
          else
            (start_date.all_day.first...end_date.all_day.last)
          end

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

      def get_products
        products_id = LeadEvent.includes(:policy_type).pluck(:policy_type_id, :title)&.uniq&.compact
        products = products_id&.map{|el| ["id", "title"].zip(el).to_h}
        render json: products, status: :ok
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
          #  @substrate = access_model(::Lead).presented.not_converted.archived.includes(:profile, :tracking_url)
          #elsif params[:filter].nil? || !!params[:filter][:archived]
          #  @substrate = access_model(::Lead).presented.not_converted.not_archived.includes(:profile, :tracking_url)
          #end
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          created_at: [:scalar, :array, :interval],
          email: [:scalar, :like],
          agency_id: [:scalar],
          status: [:scalar],
          archived: [:scalar],
          last_visit: [:interval, :scalar, :interval],
          tracking_url: {
            campaign_source: [:scalar],
            campaign_medium: [:scalar],
            campaign_name: [:scalar]
          },
          lead_events: {
            policy_type: [:scalar]
          }
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def update_allowed?
        true
      end

      def date_params
        if params[:filter].present?
          {
              start: params[:filter][:last_visit][:start],
              end: params[:filter][:last_visit][:end]
          }
        end
      end

      def need_to_download?
        params["input_file"].present? && params["input_file"]=="text/csv"
      end
      
    end
  end
end
