module TrackingUrlsMethods
  extend ActiveSupport::Concern

  included do
    def show
      render 'v2/shared/tracking_urls/show'
    end

    def index
      super(:@tracking_urls, @substrate)
      render 'v2/shared/tracking_urls/index'
    end

    def create
      @tracking_url = TrackingUrl.new(create_params)
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

    def get_leads
      @leads = @tracking_url.leads
      render 'v2/shared/leads/index'
    end

    def agency_filters
      result = []

      @agencies.select(%i[id title agency_id]).each do |agency|
        agency.branding_profiles.each do |branding_profile|
          result << agency.attributes.merge(
            branding_profile_id: branding_profile.id,
            branding_url: branding_profile.formatted_url
          )
        end
      end

      render json: result.to_json
    end

    private

    def supported_filters(called_from_orders = false)
      @calling_supported_orders = called_from_orders
      {
        agency_id: %i[scalar array],
        created_at: %i[scalar interval],
        deleted: [:scalar]
      }
    end

    def supported_orders
      supported_filters(true)
    end
  end
end
