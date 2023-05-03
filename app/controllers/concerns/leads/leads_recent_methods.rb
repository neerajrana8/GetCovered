module Concerns
  module Leads
    module LeadsRecentMethods
      extend ActiveSupport::Concern

      def index
        start_date = Date.parse(date_params[:start])
        end_date   = Date.parse(date_params[:end])

        if params[:filter].present?
          params[:filter][:last_visit] =
              if date_params[:start] == date_params[:end]
                start_date.all_day
              else
                (start_date.all_day.first...end_date.all_day.last)
              end
        end

        super(:@leads, @substrate, :account, :agency, :branding_profile)

        if need_to_download?
          ::Leads::RecentLeadsReportJob.perform_later(@leads.pluck(:id), params.as_json, current_staff.email)
          render json: { message: 'Report were sent' }, status: :ok
        else
          render 'v2/shared/leads/index'
        end
      end

      def get_products
        products_id = PolicyType.all.pluck(:id, :title)
        products = products_id&.map { |el| %w[id title].zip(el).to_h }
        render json: products, status: :ok
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          created_at: %i[scalar array interval],
          email: %i[scalar like],
          agency_id: %i[scalar array],
          agency: %i[scalar array],
          account_id: %i[scalar array],
          status: %i[scalar array],
          archived: [:scalar],
          last_visit: %i[interval scalar interval],
          tracking_url: {
            campaign_source: %i[scalar array],
            campaign_medium: %i[scalar array],
            campaign_name: %i[scalar array]
          },
          lead_events: {
            policy_type: %i[scalar array],
            policy_type_id: %i[scalar array]
          },
          branding_profile_id: %i[scalar array],
          branding_profile: {
            url: %i[scalar like]
          }
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def date_params
        if params[:filter].present? && params[:filter][:last_visit].present?
          {
            start: params[:filter][:last_visit][:start],
            end: params[:filter][:last_visit][:end]
          }
        else
          {
            start: Lead.date_of_first_lead.to_s || Time.now.beginning_of_year.to_s,
            end: Time.now.to_s
          }
        end
      end

      def need_to_download?
        params['input_file'].present? && params['input_file'] == 'text/csv'
      end

    end
  end
end
