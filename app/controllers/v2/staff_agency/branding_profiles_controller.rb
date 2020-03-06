##
# V2 StaffAgency BrandingProfiles Controller
# File: app/controllers/v2/staff_agency/branding_profiles_controller.rb

module V2
  module StaffAgency
    class BrandingProfilesController < StaffAgencyController
      
      before_action :set_branding_profile, only: [:update, :show, :destroy]

      def show
      end

      def create
        if create_allowed?
          @branding_profile = current_staff.organizable.branding_profiles.new(branding_profile_params)
          if !@branding_profile.errors.any? && @branding_profile.save
            render :show, status: :created
          else
            render json: @branding_profile.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end

      
      def update
        if update_allowed?
          if @branding_profile.update(branding_profile_params)
            render :show, status: :ok
          else
            render json: @branding_profile.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end
      
      private
      
        def view_path
          super + "/branding_profiles"
        end

        def create_allowed?
          true
        end

        
        def update_allowed?
          true
        end
        
        def set_branding_profile
          @branding_profile = access_model(::BrandingProfile, params[:id])
        end
        
        def branding_profile_params
          return({}) if params[:branding_profile].blank?
          params.require(:branding_profile).permit(
            :default, :profileable_id, :profileable_type, :title,
            :url, :footer_logo_url, :logo_url, 
            branding_profile_attributes_attributes: [ :id, :name, :value, :attribute_type], 
            styles: {}
          )
        end
        
    end
  end # module StaffAgency
end
