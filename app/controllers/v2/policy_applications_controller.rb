class V2::PolicyApplicationsController < ApplicationController
end
# V2 Policy Applications Controller
# file: +app/controllers/v2/policy_applications_controller.rb+

module V2
  class PolicyApplicationsController
    
    before_action :set_policy_application,
      only: [:show, :update]
    
    def show
    end
    
    def create
    end
    
    def update
    end
    
    private
      
      def set_policy_application
        @branding_profile = BrandingProfile.find_by_url(params["url"])  
      end
    
  end
end
