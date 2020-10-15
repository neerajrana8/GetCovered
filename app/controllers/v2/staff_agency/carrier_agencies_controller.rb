module V2
  module StaffAgency
    class CarrierAgenciesController < StaffAgencyController
      before_action :set_carrier_agency, only: %i[show update]

      def index
        super(:@carrier_agencies, CarrierAgency.where(agency: @agency))
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
          render json: standard_error(:carrier_agency_creation_error, nil, @carrier_agency.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      private

      def set_carrier_agency
        @carrier_agency = access_model(::CarrierAgency, params[:id])
      end

      def create_params
        return({}) if params[:carrier_agency].blank?

        to_return = params.require(:carrier_agency).permit(
          :carrier_id, :external_carrier_id,
          carrier_agency_authorizations_attributes: %i[state available policy_type_id zip_code_blacklist]
        ).merge(agency_id: @agency.id)
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
