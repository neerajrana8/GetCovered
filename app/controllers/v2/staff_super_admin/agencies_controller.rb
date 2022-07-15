##
# V2 StaffSuperAdmin Agencies Controller
# File: app/controllers/v2/staff_super_admin/agencies_controller.rb

module V2
  module StaffSuperAdmin
    class AgenciesController < StaffSuperAdminController
      before_action :set_agency, only: %i[update show branding_profile enable disable]

      def index
        relation =
          if params[:with_subagencies].present?
            Agency.all
          else
            Agency.where(agency_id: nil)
          end
        relation = filtered_by_carrier(relation)

        super(:@agencies, relation, :agency, :addresses)
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

      # if the carriers filters are passed, sorting won't work because of DISTINCT in the resulted query
      def sub_agencies
        result          = []
        required_fields = %i[id title agency_id enabled]

        @agencies = paginator(filtered_sub_agencies)

        @agencies.select(required_fields).each do |agency|
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

      def disable
        result = Agencies::Disable.run(agency: @agency)
        if result.valid?
          render :show, status: :ok
        else
          render json: standard_error(:disabling_failed, 'Agency was not disabled', result.errors),
                 status: 422
        end
      end

      def enable
        result = Agencies::Enable.run(agency: @agency)
        if result.valid?
          render :show, status: :ok
        else
          render json: standard_error(:disabling_failed, 'Agency was not disabled', result.errors),
                 status: 422
        end
      end

      def get_policy_types
        pts = CarrierAgencyPolicyType.includes(:policy_type, carrier_agency: :carrier).references(:policy_types, carrier_agencies: :carriers).where(carrier_agencies: { agency_id: params[:id].to_i })
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

      def set_agency
        @agency = Agency.find_by(id: params[:id])
      end

      def sub_agency_filter_params
        params[:agency_id].blank? ? nil : params.require(:agency_id)
      end

      #TODO: need to check and update as filters queries
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

        if params[:like].present?
          relation = relation.where("agencies.title ILIKE ?",
                     Agency.sanitize_sql_like(params[:like]) + "%")
        end

        passed_carriers_filters ? relation.distinct : relation
      end

      def filtered_by_carrier(sub_agency_relation)
        passed_carriers_filters = filter_params[:policy_type_id].present? || filter_params[:carrier_id].present?

        relation =
          if passed_carriers_filters
            Agency.left_joins(carrier_agencies: :carrier_agency_policy_types)
          else
            sub_agency_relation
          end

        relation = relation.where(carrier_agencies: { carrier_id: filter_params[:carrier_id] }) if filter_params[:carrier_id].present?

        if filter_params[:policy_type_id].present?
          relation = relation.where(carrier_agency_policy_types: { policy_type_id: filter_params[:policy_type_id] })
        end

        if filter_params[:title].present?
          relation = relation.where("agencies.title ILIKE ?",
                                    Agency.sanitize_sql_like(filter_params[:title][:like]) + "%")
        end

        passed_carriers_filters ? relation.distinct : relation
      end

      def filter_params
        to_return = params.permit(filter: [:policy_type_id, :carrier_id, title: [:like]])
        to_return[:filter]
      end

      def create_params
        return({}) if params[:agency].blank?

        to_return = params.require(:agency).permit(
          :agency_id, :enabled, :staff_id, :title, :tos_accepted, :producer_code,
          :whitelabel, contact_info: {}, addresses_attributes: %i[
            city country county id latitude longitude
            plus_four state street_name street_number
            street_two timezone zip_code
          ], global_agency_permission_attributes: { permissions: {} }
        )
        to_return
      end

      def update_params
        return({}) if params[:agency].blank?

        to_return = params.require(:agency).permit(
          :agency_id, :enabled, :staff_id, :title, :tos_accepted, :whitelabel, :producer_code,
          contact_info: {}, settings: {}, addresses_attributes: %i[
            city country county id latitude longitude
            plus_four state street_name street_number
            street_two timezone zip_code
          ], global_agency_permission_attributes: { permissions: {} }
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
          title: %i[scalar array interval like],
          enabled: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffSuperAdmin
end
