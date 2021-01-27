module V2
  module StaffSuperAdmin
    class TrackingUrlsController < StaffSuperAdminController
      before_action :set_tracking_url, only: [:show, :destroy, :get_leads, :get_policies]
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
          branding_profiles = agency.branding_profiles.order("url asc").to_a
          sub_agencies = agency.agencies.select(required_fields)
          sub_agencies_attr = sub_agencies.map{|sa| sa.branding_profiles.map{|bp| sa.attributes.merge("branding_url" => bp.formatted_url) } }
                                          .flatten.sort_by{|hash| hash["branding_url"] }
          result << agency.attributes.merge({ "branding_url"=> branding_profiles.first.formatted_url })
                                     .merge(sub_agencies_attr.blank? ? {} : { "agencies" => sub_agencies_attr })
          branding_profiles.drop(1).each do |branding_profile|
            result << agency.attributes.merge("branding_url" => branding_profile.formatted_url)
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

      def get_leads
        @leads = @tracking_url.leads
        render 'v2/shared/leads/index'
      end

      def get_policies
        user_ids = @tracking_url.leads.pluck(:user_id).compact
        policies_ids = PolicyUser.where(user_id: user_ids).pluck(:policy_id).compact
        @policies = Policy.where(id: policies_ids)
        render 'v2/staff_super_admin/policies/index'
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
          @substrate = access_model(::TrackingUrl)
          params[:filter][:deleted] = params[:filter][:archived] if params[:filter].present? && params[:filter][:archived].present?
          params[:filter].delete(:archived)
        end
      end

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
end
