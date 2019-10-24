##
# V2 StaffAgency BrandingProfiles Controller
# File: app/controllers/v2/staff_agency/branding_profiles_controller.rb

module V2
  module StaffAgency
    class BrandingProfilesController < StaffAgencyController
      
      before_action :set_branding_profile,
        only: [:update, :show]
      
      def show
      end
      
      def update
        if update_allowed?
          if @branding_profile.update(update_params)
            render :show,
              status: :ok
          else
            render json: @branding_profile.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/branding_profiles"
        end
        
        def update_allowed?
          true
        end
        
        def set_branding_profile
          @branding_profile = access_model(::BrandingProfile, params[:id])
        end
        
        def update_params
          return({}) if params[:branding_profile].blank?
          params.require(:branding_profile).permit(
            :default, :id, :profileable_id, :profileable_type, :title,
            :url, styles: {}
          )
        end
        
    end
  end # module StaffAgency
end
