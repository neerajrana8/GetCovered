##
# V2 StaffAgency Insurables Controller
# File: app/controllers/v2/staff_agency/insurables_controller.rb

module V2
  module StaffSuperAdmin
    class InsurablesController < StaffSuperAdminController
      alias super_index index

      before_action :set_insurable, only: %i[show coverage_report policies related_insurables destroy update]
      before_action :set_master_policies, only: :show
      before_action :set_agency, only: [:create]

      def index
        super_index(:@insurables, Insurable.all)
      end

      def show; end

      def create
        if create_allowed?
          @insurable = @agency.insurables.new(insurable_params)
          if @insurable.errors.none? && @insurable.save_as(current_staff)
            render :show,
                   status: :created
          else
            render json: @insurable.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def coverage_report
        render json: @insurable.coverage_report
      end

      def destroy
        if @insurable.destroy
          render json: { success: true },
                 status: :ok
        else
          render json: { success: false },
                 status: :unprocessable_entity
        end
      end

      def policies
        insurable_units_ids =
          if InsurableType::UNITS_IDS.include?(@insurable.insurable_type_id)
            @insurable.id
          else
            [@insurable.units&.pluck(:id), @insurable.id, @insurable.insurables.ids].flatten.uniq.compact
          end

        policies_query = Policy.joins(:insurables).where(insurables: { id: insurable_units_ids }).order(created_at: :desc)

        @policies = paginator(policies_query)
        render :policies, status: :ok
      end

      def related_insurables
        @insurables = super_index(:@insurables, @insurable.insurables)
        render :index, status: :ok
      end

      def update
        if update_allowed?
          if @insurable.update_as(current_staff, insurable_params)
            render :show,
                   status: :ok
          else
            render json: @insurable.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      # the same as in tracking urls - need to refactor and combine filters in one place
      def agency_filters
        result          = []
        required_fields = %i[id title agency_id]

        @agencies = Agency.main_agencies # paginator(Agency.main_agencies)

        @agencies.select(required_fields).each do |agency|
          branding_profiles = agency.branding_profiles.order('url asc').to_a
          sub_agencies = agency.agencies.select(required_fields)
          sub_agencies_attr = sub_agencies.map { |sa| sa.branding_profiles.map { |bp| sa.attributes.merge('branding_url' => bp.formatted_url) } }
            .flatten.sort_by { |hash| hash['branding_url'] }
          result << agency.attributes.merge('branding_url' => branding_profiles.first.formatted_url)
            .merge(sub_agencies_attr.blank? ? {} : { 'agencies' => sub_agencies_attr })
          branding_profiles.drop(1).each do |branding_profile|
            result << agency.attributes.merge('branding_url' => branding_profile.formatted_url)
          end
        end

        render json: result.to_json
      end

      private

      def view_path
        super + '/insurables'
      end

      def update_allowed?
        true
      end

      def create_allowed?
        true
      end

      def set_insurable
        @insurable = Insurable.find(params[:id])
      end

      def set_agency
        @agency = Agency.find_by_id(insurable_params[:agency_id])
        render json: standard_error(:agency_was_not_found), status: :not_found  if @agency.nil?
      end

      def set_master_policies
        if @insurable.unit?
          @master_policy_coverage =
            @insurable.policies.current.where(policy_type_id: PolicyType::MASTER_COVERAGE_ID).take
          @master_policy = @master_policy_coverage&.policy
        else
          @master_policy =
            @insurable.policies.current.where(policy_type_id: PolicyType::MASTER_ID).take
          @master_policy_coverage = nil
        end
      end

      def insurable_params
        return({}) if params[:insurable].blank?

        to_return = params.require(:insurable).permit(
            :category, :covered, :enabled, :insurable_id,
            :insurable_type_id, :title, :agency_id, :account_id, addresses_attributes: %i[
              city country county id latitude longitude
              plus_four state street_name street_number
              street_two timezone zip_code
            ]
          )

        existed_ids = to_return[:addresses_attributes]&.map { |addr| addr[:id] }

        unless @insurable.blank? || existed_ids.nil? || existed_ids.compact.blank?
          (@insurable.addresses.pluck(:id) - existed_ids).each do |id|
            to_return[:addresses_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end
        to_return
      end

      def update_params
        return({}) if params[:insurable].blank?

        to_return = params.require(:insurable).permit(
            :covered, :enabled, :insurable_id,
            :title, :agency_id, :account_id, addresses_attributes: %i[
              city country county id latitude longitude
              plus_four state street_name street_number
              street_two timezone zip_code
            ]
          )

        existed_ids = to_return[:addresses_attributes]&.map { |addr| addr[:id] }

        unless @insurable.blank? || existed_ids.nil? || existed_ids.compact.blank?
          (@insurable.addresses.pluck(:id) - existed_ids).each do |id|
            to_return[:addresses_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end
        to_return
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: %i[scalar array],
          title: %i[scalar like],
          permissions: %i[scalar array],
          insurable_type_id: %i[scalar array],
          insurable_id: %i[scalar array],
          account_id: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
