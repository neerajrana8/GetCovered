##
# V2 StaffSuperAdmin BrandingProfiles Controller
# File: app/controllers/v2/staff_super_admin/branding_profiles_controller.rb

module V2
  module StaffSuperAdmin
    class BrandingProfileAttributesController < StaffSuperAdminController

      before_action :set_branding_profile_attribute, only: %i[destroy]

      # spread the branding attribute to all branding profiles without rewriting
      def copy
        result = BrandingProfileAttributes::Copy.run!(branding_profile_attributes_ids: params[:ids])
        if result.success?
          head :ok
        else
          render json: result.failure, status: 422
        end
      end

      # spread the branding attribute to all branding profiles with rewriting
      def force_copy
        result =
          BrandingProfileAttributes::Copy.run!(branding_profile_attributes_ids: params[:ids], force: true)
        if result.success?
          head :ok
        else
          render json: result.failure, status: 422
        end
      end

      def destroy
        if @branding_profile_attribute.destroy
          render json: { success: true }, status: :ok
        else
          render json: { success: false }, status: :unprocessable_entity
        end
      end

      private
              
      def set_branding_profile_attribute
        @branding_profile_attribute = BrandingProfileAttribute.find(params[:id])
      end
    end
  end
end
