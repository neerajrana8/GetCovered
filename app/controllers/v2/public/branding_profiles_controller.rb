##
# V2 Public Branding Profiles Controller
# File: app/controllers/v2/public/branding_profiles_controller.rb

module V2
  module Public
    class BrandingProfilesController < PublicController
	  	before_action :set_branding_profile, only: [:show]

      def show
      end
      
      private
      
      def set_branding_profile
        @branding_profile = BrandingProfile.find(params[:id])
      end
	  end
	end
end