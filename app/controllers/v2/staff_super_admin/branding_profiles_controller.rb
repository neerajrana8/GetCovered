module V2
  module StaffSuperAdmin
    class BrandingProfilesController < StaffSuperAdminController
      before_action :set_branding_profile, only: [:update, :show, :destroy]
      
      def index
        super(:@branding_profiles, BrandingProfile)
      end


      def show
      end

      def create
        @branding_profile = BrandingProfile.new(create_params)
        if !@branding_profile.errors.any? && @branding_profile.save
          render :show, status: :created
        else
          render json: @branding_profile.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if update_allowed?
          if @branding_profile.update(update_params)
            render :show, status: :ok
          else
            render json: @branding_profile.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end

      def destroy
        if destroy_allowed?
          if @branding_profile.destroy
            render json: { success: true }, status: :ok
          else
            render json: { success: false }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },status: :unauthorized
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

        def branding_profile_params
          return({}) if params[:branding_profile].blank?
          params.require(:branding_profile).permit(
            :default, :id, :profileable_id, :profileable_type, :title,
            :url, :footer_logo_url, :logo_url, :subdomain, :subdomain_test,
            branding_profile_attributes_attributes: [ :id, :name, :value, :attribute_type], 
            styles: {}
          )
        end
    end
  end
end
