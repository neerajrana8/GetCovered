##
# V2 StaffAgency Agencies Controller
# File: app/controllers/v2/staff_agency/agencies_controller.rb

module V2
  module StaffAgency
    class AgenciesController < StaffAgencyController

      before_action :set_agency, only: [:update, :show, :branding_profile]

      def index
        if params[:short]
          super(:@agencies, current_staff.organizable.agencies)
        else
          super(:@agencies, current_staff.organizable.agencies, :agency)
        end
      end

      def sub_agencies_index
        result = []
        required_fields = %i[id title agency_id]

        if current_staff.organizable_id == ::Agency::GET_COVERED_ID
          Agency.where(agency_id: nil).select(required_fields).each do |agency|
            sub_agencies = agency.agencies.select(required_fields)
            result << if sub_agencies.any?
              agency.attributes.reverse_merge(agencies: sub_agencies.map(&:attributes))
            else
              agency.attributes
            end
          end
        else
          result = current_staff.organizable.agencies.select(required_fields).map(&:attributes)
        end

        render json: result.to_json
      end

      def show; end

      def create
        if create_allowed?
          @agency = current_staff.organizable.agencies.new(create_params)
          if @agency.errors.none? && @agency.save_as(current_staff)
            render :show, status: :created
          else
            render json: @agency.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def update
        if update_allowed?
          if @agency.update_as(current_staff, update_params)
            render :show, status: :ok
          else
            render json: @agency.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def branding_profile
        @branding_profile = BrandingProfile.where(profileable: @agency).take
        if @branding_profile.present?
          render '/v2/staff_agency/branding_profiles/show', status: :ok
        else
          render json: { success: false, errors: ['Agency does not have a branding profile'] }, status: :not_found
        end
      end

      private

      def view_path
        super + '/agencies'
      end

      def create_allowed?
        true
      end

      def update_allowed?
        true
      end

      def set_agency
        @agency =
          if current_staff.organizable_type == 'Agency' && current_staff.organizable_id.to_s == params[:id]
            current_staff.organizable
          else
            current_staff.organizable.agencies.find_by(id: params[:id])
          end
      end

      def create_params
        return({}) if params[:agency].blank?

        to_return = params.require(:agency).permit(
          :staff_id, :title, :tos_accepted, :whitelabel,
          contact_info: {}, addresses_attributes: %i[
            city country county id latitude longitude
            plus_four state street_name street_number
            street_two timezone zip_code
          ]
        )
        to_return
      end

      def update_params
        return({}) if params[:agency].blank?

        params.require(:agency).permit(
          :staff_id, :title, :tos_accepted, :whitelabel,
          contact_info: {}, settings: {}, addresses_attributes: %i[
            city country county id latitude longitude
            plus_four state street_name street_number
            street_two timezone zip_code
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
  end # module StaffAgency
end
