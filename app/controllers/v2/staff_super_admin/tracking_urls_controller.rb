module V2
  module StaffSuperAdmin
    class TrackingUrlsController < StaffSuperAdminController
      include ActionController::Caching

      before_action :set_tracking_url, only: %i[show destroy get_leads get_policies]
      before_action :set_substrate, only: :index
      before_action :set_agencies, only: :agency_filters

      include TrackingUrlsMethods

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
            :campaign_name, :campaign_term, :campaign_content, :agency_id, :branding_profile_id
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

      def set_agencies
        @agencies = Agency.all
      end
    end
  end
end
