##
# V2 StaffAccount BrandingProfiles Controller
# File: app/controllers/v2/staff_account/branding_profiles_controller.rb

module V2
  module StaffAccount
    class BrandingProfilesController < StaffAccountController
      
      before_action :set_branding_profile, only: %i[update show]      
      before_action :set_substrate, only: [:index]
      
      def index
        super(:@branding_profiles, @substrate)
      end
      
      def show; end
      
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
        super + '/branding_profiles'
      end
        
      def update_allowed?
        true
      end
        
      def set_branding_profile
        @branding_profile = access_model(::BrandingProfile, params[:id])
      end
        
      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::BrandingProfile)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.branding_profiles
        end
      end
        
      def update_params
        return({}) if params[:branding_profile].blank?

        params.require(:branding_profile).permit(
          :default, :id, :profileable_id, :profileable_type, :title,
          :url, styles: {}
        )
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          profileable_type: [:scalar],
          profileable_id: [:scalar]
        }
      end

      def supported_orders
        supported_filters(true)
      end
        
    end
  end # module StaffAccount
end
