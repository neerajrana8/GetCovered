##
# V2 Public Branding Profiles Controller
# File: app/controllers/v2/public/branding_profiles_controller.rb

module V2
  module Public
    class BrandingProfilesController < PublicController
	  	before_action :set_branding_profile, only: [:show]

      def show
        render :show, status: :ok
      end
      
      private
      
      def set_branding_profile
        subdomain = ActionDispatch::Http::URL.extract_subdomain(request.original_url, 1)
        if subdomain.empty?
          @branding_profile = BrandingProfile.find_by(title: 'GetCovered')
        else
          @branding_profile = BrandingProfile.find_by(subdomain: subdomain)
        end
        @branding_profile ||= BrandingProfile.find_by(title: 'GetCovered')
      end
	  end
	end
end