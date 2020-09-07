##
# V2 StaffSuperAdmin Agencies Controller
# File: app/controllers/v2/staff_super_admin/agencies_controller.rb

module V2
  module StaffSuperAdmin
    class AgenciesController < StaffSuperAdminController
      
      before_action :set_agency, only: [:update, :show, :branding_profile]
            
      def index
        if params[:short]
          super(:@agencies, Agency)
        else
          super(:@agencies, Agency, :agency)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @agency = Agency.new(create_params)
          if !@agency.errors.any? && @agency.save_as(current_staff)
            render :show,
              status: :created
          else
            render json: @agency.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end

      def sub_agencies_index
        result = []
        required_fields = %i[id title agency_id]

        Agency.where(agency_id: nil).select(required_fields).each do |agency|
          sub_agencies = agency.agencies.select(required_fields)
          result << if sub_agencies.any?
            agency.attributes.reverse_merge(agencies: sub_agencies.map(&:attributes))
          else
            agency.attributes
          end
        end

        render json: result.to_json
      end
      
      def update
        if update_allowed?
          if @agency.update_as(current_staff, update_params)
            render :show,
              status: :ok
          else
            render json: @agency.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end

      def branding_profile
        @branding_profile = BrandingProfile.where(profileable: @agency).take
        if @branding_profile.present?
          render '/v2/staff_super_admin/branding_profiles/show', status: :ok
        else
          render json: { success: false, errors: ['Agency does not have a branding profile'] }, status: :not_found
        end
      end
      
      
      private
      
        def view_path
          super + "/agencies"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_agency
          @agency = Agency.find_by(id: params[:id])
        end
                
        def create_params
          return({}) if params[:agency].blank?
          to_return = params.require(:agency).permit(
            :agency_id, :enabled, :staff_id, :title, :tos_accepted,
            :whitelabel, contact_info: {}, addresses_attributes: [
              :city, :country, :county, :id, :latitude, :longitude,
              :plus_four, :state, :street_name, :street_number,
              :street_two, :timezone, :zip_code
            ]
          )
          return(to_return)
        end
        
        def update_params
          return({}) if params[:agency].blank?
          params.require(:agency).permit(
            :enabled, :staff_id, :title, :tos_accepted, :whitelabel,
            contact_info: {}, settings: {}, addresses_attributes: [
              :city, :country, :county, :id, :latitude, :longitude,
              :plus_four, :state, :street_name, :street_number,
              :street_two, :timezone, :zip_code
            ]
          )
        end
        
        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffSuperAdmin
end
