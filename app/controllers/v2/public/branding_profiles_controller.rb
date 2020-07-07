##
# V2 Public Branding Profiles Controller
# File: app/controllers/v2/public/branding_profiles_controller.rb

module V2
  module Public
    class BrandingProfilesController < PublicController
      before_action :set_branding_profile, only: [:show, :faqs]
      before_action :set_branding_profile_by_subdomain, only: [:show_by_subdomain]

      def show
        render :show, status: :ok
      end

      def faqs
        @branding_profile = BrandingProfile.includes(:faqs).find(params[:id]) || []
        render :faqs, status: :ok
      end

      def show_by_subdomain
        render :show, status: :ok
      end
      
      private

      def set_branding_profile_by_subdomain
        request_url = request.headers['origin'] || request.referer
        host = request_url.present? ? URI(request_url).host&.delete_prefix('www.') : nil
        @branding_profile = BrandingProfile.find_by(url: host) || BrandingProfile.find_by(title: 'GetCovered')
      end
      
      def set_branding_profile
        @branding_profile = BrandingProfile.find(params[:id])
      end
    end
  end
end
