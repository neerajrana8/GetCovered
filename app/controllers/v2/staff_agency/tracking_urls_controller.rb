module V2
  module StaffAgency
    class TrackingUrlsController < StaffAgencyController
  
      before_action :set_tracking_url, only: [:show, :destroy]
      before_action :set_substrate, only: :index

      def create
        @tracking_url = TrackingUrl.new(create_params)
        @tracking_url.agency = current_staff.organizable
        if @tracking_url.save
          render 'v2/shared/tracking_urls/show', status: :created
        else
          render json: @tracking_url.errors,
                 status: :unprocessable_entity
        end
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
        @tracking_url = access_model(::TrackingUrl).not_deleted.find(params[:id])
      end

      def create_params
        return({}) if params[:tracking_url].blank?

        to_return = params.require(:tracking_url).permit(
            :landing_page, :campaign_source, :campaign_medium,
            :campaign_name, :campaign_term, :campaign_content
        )
        to_return
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::TrackingUrl).not_deleted
        end
      end

    end
  end
end
