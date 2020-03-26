##
# V2 Public Branding Profiles Controller
# File: app/controllers/v2/public/branding_profiles_controller.rb

module V2
  module Public
    class BrandingProfilesController < PublicController
	  	before_action :set_branding_profile, only: [:show]
	  	before_action :set_branding_profile_by_subdomain, only: [:show_by_subdomain]

      def show
        render :show, status: :ok
      end

      def show_by_subdomain
        render :show, status: :ok
      end
      
      private

      def set_branding_profile_by_subdomain
        subdomain = ActionDispatch::Http::URL.extract_subdomain(request.headers['origin'], 1)
        if subdomain.empty?
          @branding_profile = BrandingProfile.find_by(title: 'GetCovered')
        else
          @branding_profile = BrandingProfile.find_by(subdomain: subdomain)
        end
        @branding_profile ||= BrandingProfile.find_by(title: 'GetCovered')
      end
      
      def set_branding_profile
        @branding_profile = BrandingProfile.find(params[:id])
      end
	  end
	end
end