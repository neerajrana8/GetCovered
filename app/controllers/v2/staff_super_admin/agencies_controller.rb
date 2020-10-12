##
# V2 StaffSuperAdmin Agencies Controller
# File: app/controllers/v2/staff_super_admin/agencies_controller.rb

module V2
  module StaffSuperAdmin
    class AgenciesController < StaffSuperAdminController

      before_action :set_agency, only: [:update, :show, :branding_profile]
      before_action :default_filter, only: [:index, :show]

      def index
        if params[:short]
          super(:@agencies, Agency)
        else
          super(:@agencies, Agency, :agency)
        end
      end

      def show; end

      def create
        if create_allowed?
          outcome = Agencies::Create.run(agency_params: create_params.to_h)
          if outcome.valid?
            @agency = outcome.result
            render :show, status: :created
          else
            render json: standard_error(:agency_creation_error, nil, outcome.errors.full_messages),
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

        Agency.where(agency_id: sub_agency_filter_params).select(required_fields).each do |agency|
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

        #return only agencies
        def default_filter
          params[:filter] = {"agency_id"=> "_NULL_"} if params[:filter].blank?
        end

        def sub_agency_filter_params
          params[:agency_id].blank? ? nil : params.require(:agency_id)
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
          to_return = params.require(:agency).permit(
              :agency_id, :enabled, :staff_id, :title, :tos_accepted, :whitelabel,
            contact_info: {}, settings: {}, addresses_attributes: [
              :city, :country, :county, :id, :latitude, :longitude,
              :plus_four, :state, :street_name, :street_number,
              :street_two, :timezone, :zip_code
            ]
          )

          existed_ids = to_return[:addresses_attributes]&.map { |addr| addr[:id] }

          unless @agency.blank? || existed_ids.nil? || existed_ids.compact.blank?
            (@agency.addresses.pluck(:id) - existed_ids).each do |id|
              to_return[:addresses_attributes] <<
                  ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
            end
          end
          to_return
        end

        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
              agency_id: %i[scalar array],
              id: %i[scalar array]
          }
        end

        def supported_orders
          supported_filters(true)
        end

    end
  end # module StaffSuperAdmin
end
