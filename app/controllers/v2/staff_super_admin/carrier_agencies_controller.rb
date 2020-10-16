module V2
  module StaffSuperAdmin
    class CarrierAgenciesController < StaffSuperAdminController
      before_action :set_carrier_agency, only: %i[show update]

      def index
        super(:@carrier_agencies, CarrierAgency.all)
        render template: 'v2/shared/carrier_agencies/index', status: :ok
      end

      def show
        render template: 'v2/shared/carrier_agencies/show', status: :ok
      end

      def create
        @carrier_agency = CarrierAgency.create(create_params)
        if @carrier_agency.errors.blank?
          render template: 'v2/shared/carrier_agencies/show', status: :created
        else
          render json: standard_error(:carrier_agency_create_error, nil, @carrier_agency.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      def update
        if @carrier_agency.update_as(current_staff, update_params)
          render template: 'v2/shared/carrier_agencies/show', status: :ok
        else
          render json: standard_error(:carrier_agency_update_errors, nil, @carrier_agency.errors.full_messagess),
                 status: :unprocessable_entity
        end
      end

      private

      def set_carrier_agency
        @carrier_agency = CarrierAgency.find(params[:id])
      end

      def create_params
        return({}) if params[:carrier_agency].blank?

        to_return = params.require(:carrier_agency).permit(
          :carrier_id, :external_carrier_id, :agency_id,
          carrier_agency_authorizations_attributes: %i[state available policy_type_id zip_code_blacklist]
        )
        to_return
      end

      def update_params
        to_return = params.require(:carrier_agency).permit(
          :id, :carrier_id, :external_carrier_id, :agency_id,
          carrier_agency_authorizations_attributes: %i[id state available policy_type_id zip_code_blacklist]
        )

        existed_ids = to_return[:carrier_agency_authorizations_attributes]&.map { |cpt| cpt[:id] }

        unless @carrier_agency.blank? || existed_ids.nil?
          (@carrier_agency.carrier_agency_authorizations.pluck(:id) - existed_ids).each do |id|
            to_return[:carrier_agency_authorizations_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end
        to_return
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          carrier_id: %i[scalar array],
          agency_id: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
