# V2 Branding Profiles Controller
# file: +app/controllers/v2/branding_profiles_controller.rb+

module V2
  class BrandingProfilesController
    
    before_action :set_branding_profile
    
    def show
    end
    
    private
      
      def set_branding_profile
        @branding_profile = BrandingProfile.find_by_url(params["url"])  
      end
    
  end
end
