##
# V2 StaffAgency Agencies Controller
# File: app/controllers/v2/staff_agency/agencies_controller.rb

module V2
  module StaffAgency
    class AgenciesController < StaffAgencyController

      before_action :set_agency, only: [:update, :show, :branding_profile, :get_policy_types]
      check_privileges 'agencies.details' => %i[create show]

      def index
        if params[:short]
          super(:@agencies, current_staff.organizable.agencies)
        else
          super(:@agencies, current_staff.organizable.agencies, :agency)
        end
      end

      # if the carriers filters are passed, sorting won't work because of DISTINCT in the resulted query
      def sub_agencies
        result = []
        required_fields = %i[id title agency_id enabled]

        @agencies = paginator(filtered_sub_agencies)

        if current_staff.getcovered_agent?
          @agencies.select(required_fields).each do |agency|
            sub_agencies = agency.agencies.select(required_fields)
            result << if sub_agencies.any?
              agency.attributes.reverse_merge(agencies: sub_agencies.map(&:attributes))
            else
              agency.attributes
            end
          end
        else
          result = paginator(current_staff.organizable.agencies).select(required_fields).map(&:attributes)
        end

        render json: result.to_json
      end

      def show; end

      def create
        if create_allowed?
          outcome = ::Agencies::Create.run(
            agency_params: create_params.to_h,
            parent_agency: current_staff.organizable,
            creator: current_staff
          )
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
      
      def get_policy_types
        pts = CarrierAgencyPolicyType.includes(:policy_type, carrier_agency: :carrier).references(:policy_types, carrier_agencies: :carriers).where(carrier_agencies: { agency_id: @agency&.id })
                                     .group_by{|capt| capt.policy_type_id }
                                     .transform_values{|capts| { id: capts.first.policy_type_id, title: capts.first.policy_type.title, carriers: capts.map{|capt| { id: capt.carrier_agency.carrier_id, title: capt.carrier_agency.carrier.title } }.uniq } }
                                     .values.sort_by{|v| v[:title] }
          
        render json: pts,
          status: 200
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

      def filtered_sub_agencies
        passed_carriers_filters = params[:policy_type_id].present? || params[:carrier_id].present?

        relation =
          if passed_carriers_filters
            Agency.left_joins(carrier_agencies: :carrier_agency_policy_types)
          else
            Agency
          end

        relation = relation.where(agency_id: sub_agency_filter_params)
        relation = relation.where(carrier_agencies: { carrier_id: params[:carrier_id] }) if params[:carrier_id].present?
        if params[:policy_type_id].present?
          relation = relation.where(carrier_agency_policy_types: { policy_type_id: params[:policy_type_id] })
        end

        passed_carriers_filters ? relation.distinct : relation
      end

      def sub_agency_filter_params
        params[:agency_id].blank? ? nil : params.require(:agency_id)
      end

      def set_agency
        @agency =
          if current_staff.organizable_type == 'Agency' && current_staff.organizable_id.to_s == params[:id]
            current_staff.organizable
          elsif current_staff.getcovered_agent?
            Agency.find(params[:id])
          else
            current_staff.organizable.agencies.find(params[:id])
          end
      end

      def create_params
        return({}) if params[:agency].blank?

        to_return = params.require(:agency).permit(
          :staff_id, :title, :tos_accepted, :whitelabel, :producer_code,
          contact_info: {}, global_agency_permission_attributes: { permissions: {} }, addresses_attributes: %i[
            city country county id latitude longitude
            plus_four state street_name street_number
            street_two timezone zip_code
          ]
        )
        to_return
      end

      def update_params
        return({}) if params[:agency].blank?

        to_return = params.require(:agency).permit(
          :staff_id, :title, :tos_accepted, :whitelabel, :producer_code,
          contact_info: {}, settings: {}, global_agency_permission_attributes: { permissions: {} }, addresses_attributes: %i[
            city country county id latitude longitude
            plus_four state street_name street_number
            street_two timezone zip_code
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
          id: %i[scalar array],
          created_at: %i[scalar array interval],
          updated_at: %i[scalar array interval],
          title: %i[scalar array interval like],
          enabled: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffAgency
end
