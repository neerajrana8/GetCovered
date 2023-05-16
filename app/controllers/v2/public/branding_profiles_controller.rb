##
# V2 Public Branding Profiles Controller
# File: app/controllers/v2/public/branding_profiles_controller.rb

module V2
  module Public
    class BrandingProfilesController < PublicController
      before_action :set_branding_profile, only: [:show, :faqs]
      before_action :set_branding_profile_by_subdomain, only: [:show_by_subdomain]

      def show
        if @branding_profile.blank?
          render json: standard_error(:branding_profile_not_found,'branding profile not found for this id'),
                 status: :not_found
        else
          render :show, status: :ok
        end
      end

      def faqs
        @branding_profile = BrandingProfile.includes(:faqs).find(params[:id]) || []
        if @branding_profile.blank?
          render json: standard_error(:branding_profile_not_found,'branding profile not found for this id'),
                 status: :not_found
        else
          render :faqs, status: :ok
        end
      end

      def show_by_subdomain
        render :show, status: :ok
      end

      private

      def set_branding_profile_by_subdomain
        request_url = request.headers['origin'] || request.referer
        host = request_url.present? ? URI(request_url).host&.delete_prefix('www.') : nil

        @branding_profile =
          if host.present? && Rails.env.to_sym != :production
            agency_prefix = host.split('.').first
            agency = Agency.find_by_slug(agency_prefix)
            agency&.branding_profiles&.where(enabled: true)&.take
          end

        # if there is no agency with that slug or it is the production, finds by the host or uses the default profile
        @branding_profile ||= (BrandingProfile.where(enabled: true).find_by_url(host) || BrandingProfile.global_default)
      end

      def set_branding_profile
        @branding_profile = BrandingProfile.where(enabled: true).find(params[:id])
      end
    end
  end
end
