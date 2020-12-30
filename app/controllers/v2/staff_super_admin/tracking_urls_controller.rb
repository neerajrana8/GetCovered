module V2
  module StaffSuperAdmin
    class TrackingUrlsController < StaffSuperAdminController
      before_action :set_tracking_url, only: [:show, :destroy]
      before_action :set_substrate, only: :index

      def create
        @tracking_url = TrackingUrl.new(create_params)
        if @tracking_url.save
          render 'v2/shared/tracking_urls/show', status: :created
        else
          render json: @tracking_url.errors,
                 status: :unprocessable_entity
        end
      end

      def agency_filters
        result          = []
        required_fields = %i[id title agency_id]

        @agencies = Agency.main_agencies #paginator(Agency.main_agencies)

        @agencies.select(required_fields).each do |agency|
          sub_agencies = agency.agencies.select(required_fields)
          result << if sub_agencies.any?
                      sub_agencies_attr = sub_agencies.map{|el| el.attributes.merge("branding_url"=> el.branding_url)}
                      agency_attr = agency.attributes.reverse_merge("agencies"=> sub_agencies_attr)
                      agency_attr.merge("branding_url"=> agency.branding_url)
                    else
                      agency_attr = agency.attributes
                      agency_attr.merge("branding_url"=> agency.branding_url)
                    end
        end

        render json: result.to_json
      end

      def destroy
        @tracking_url.deleted = true
        if @tracking_url.save
          render json: { success: true }, status: :no_content
        else
          render json: @tracking_url.errors, status: :unprocessable_entity
        end
      end

      def show
        render 'v2/shared/tracking_urls/show'
      end

      def index
        super(:@tracking_urls, @substrate)
        render 'v2/shared/tracking_urls/index'
      end


      private

      def set_tracking_url
        @tracking_url = TrackingUrl.not_deleted.find(params[:id])
      end

      def create_params
        return({}) if params[:tracking_url].blank?

        to_return = params.require(:tracking_url).permit(
            :landing_page, :campaign_source, :campaign_medium,
            :campaign_name, :campaign_term, :campaign_content, :agency_id
        )
        to_return
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = TrackingUrl.not_deleted
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            agency_id: %i[scalar array],
            created_at: %i[scalar interval]
        }
      end

      def supported_orders
        supported_filters(true)
      end

    end
  end
end
