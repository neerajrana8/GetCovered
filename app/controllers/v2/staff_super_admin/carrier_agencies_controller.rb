module V2
  module StaffSuperAdmin
    class CarrierAgenciesController < StaffSuperAdminController
      before_action :set_carrier_agency, only: %i[show update update_policy_types unassign]

      def index
        super(:@carrier_agencies, CarrierAgency.all)
        render template: 'v2/shared/carrier_agencies/index', status: :ok
      end

      def show
        render template: 'v2/shared/carrier_agencies/show', status: :ok
      end

      def create
        # Use CarriersController#assign_agency_to_carrier instead!
        #
        # agency = Agency.find_by(id: create_params[:agency_id])
        # carrier = Carrier.find_by(id: create_params[:carrier_id])
        #
        # if agency.nil? || carrier.nil?
        #  render json: standard_error(:something_went_wrong, 'Data Missing', {}), status: :unprocessable_entity
        # else
        #  if carrier.agencies.include?(agency)
        #    render json: { message: 'This agency has been already assigned to this carrier' }, status: :unprocessable_entity
        #  else
        #    if carrier.agencies << agency
        #      render json: { message: 'Carrier was added to the agency' }, status: :ok
        #    else
        #      render json: standard_error(:something_went_wrong, "#{agency.title} could not be assigned to #{carrier.title}", {}), status: :unprocessable_entity
        #    end
        #  end
        # end
      end

      def update
        if @carrier_agency.update_as(current_staff, update_params)
          render template: 'v2/shared/carrier_agencies/show', status: :ok
        else
          render json: standard_error(:carrier_agency_update_errors, nil, @carrier_agency.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      def update_policy_types
        if @carrier_agency.update_as(current_staff, update_types_params)
          render template: 'v2/shared/carrier_agencies/show', status: :ok
        else
          render json: standard_error(:carrier_agency_update_errors, nil, @carrier_agency.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      def unassign
        if @carrier_agency.destroy
          render json: { message: "Agency ##{@carrier_agency.agency_id} successfully unassigned" },
                 status: :ok
        else
          render json: standard_error(:unassignment_error, "Agency ##{@carrier_agency.agency_id} was not unassigned"),
                 status: :bad_request
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
      
      def update_types_params
        return({}) if params[:carrier].blank?

        to_return = params.require(:carrier_agency).permit(
           carrier_agency_policy_types_attributes: [
             :id, :policy_type_id,
             commission_strategy_attributes: [:percentage]
           ]
         )

        existed_ids = to_return[:carrier_agency_policy_types_attributes]&.map { |cpt| cpt[:id] }

        unless @carrier_agency.blank? || existed_ids.nil?
          (@carrier_agency.carrier_agency_policy_types.pluck(:id) - existed_ids).each do |id|
            to_return[:carrier_agency_policy_types_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end
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
          agency_id: %i[scalar array],
          created_at: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
