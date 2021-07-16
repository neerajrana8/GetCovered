##
# V2 StaffAgency BrandingProfiles Controller
# File: app/controllers/v2/staff_agency/branding_profiles_controller.rb

module V2
  module StaffAccount
    class BrandingProfileAttributesController < StaffAccountController
      
      before_action :set_branding_profile_attribute, only: [:destroy]

      def destroy
        if @branding_profile_attribute.destroy
          render json: { success: true }, status: :ok
        else
          render json: { success: false }, status: :unprocessable_entity
        end
      end

      private
              
      def set_branding_profile_attribute
        @branding_profile_attribute = 
          BrandingProfileAttribute.
            joins(:branding_profile).
            where(branding_profiles: {profileable: @account}).
            find(params[:id])
      end
                
    end
  end # module StaffAgency
end
