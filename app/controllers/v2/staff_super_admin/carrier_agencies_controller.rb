module V2
  module StaffSuperAdmin
    class CarrierAgenciesController < StaffSuperAdminController
      before_action :set_carrier_agency, only: %i[show update]

      def index
        super(:@carrier_agencies, CarrierAgency.all, :agency, :carrier)
        render template: 'v2/shared/carrier_agencies/index', status: :ok
      end

      def show
        render template: 'v2/shared/carrier_agencies/show', status: :ok
      end

      def create
        # Same as CarriersController#assign_agency_to_carrier...
        agency = Agency.find_by(id: create_params[:agency_id])
        carrier = Carrier.find_by(id: create_params[:carrier_id])
        unless agency.nil? || carrier.nil?
          if carrier.agencies.include?(agency)
            render json: { message: 'This agency has been already assigned to this carrier' }, status: :unprocessable_entity
          else
            created = ::CarrierAgency.create(create_params)
            if created.id
              render json: { message: 'Carrier was added to the agency' }, status: :ok
            else
              render json: standard_error(:something_went_wrong, "#{agency.title} could not be assigned to #{carrier.title}", created.errors.full_messages), status: :unprocessable_entity
            end
          end
        end
      end

      def update
        if @carrier_agency.update_as(current_staff, update_params)
          render template: 'v2/shared/carrier_agencies/show', status: :ok
        else
          render json: standard_error(:carrier_agency_update_errors, nil, @carrier_agency.errors.full_messages),
                 status: :unprocessable_entity
        end
      end
      
      def parent_info
        to_return = {
          record_id: nil,
          parent_id: nil,
          parent_agency_id: nil,
          parent_agency_title: nil,
          parent_commission_rate: nil
          
        }
        agency = Agency.find(params[:agency_id])
        carrier = Agency.find(params[:carrier_id])
        if agency.master_agency
          
        elsif agency.agency.nil?
        else
        end
      end

      private

      def set_carrier_agency
        @carrier_agency = !params[:id].blank? ? CarrierAgency.find(params[:id]) : CarrierAgency.where(carrier_id: params[:carrier_id], agency_id: params[:agency_id]).take
      end

      def create_params
        params.require(:carrier_agency).permit(
          :carrier_id,
          :agency_id,
          :external_carrier_id,
          # commented out for now because they are automatically created by callback in the model at the moment, without checks for whether the user has manually supplied them
          #carrier_agency_authorizations_attributes: %i[state available policy_type_id zip_code_blacklist],
          carrier_agency_policy_types_attributes: [
            :policy_type_id,
            commission_strategy_attributes: [
              :percentage
            ]
          ]
        )
      end

      def update_params
        to_return = params.require(:carrier_agency).permit(
          :carrier_id, :agency_id, :external_carrier_id,
          carrier_agency_authorizations_attributes: %i[id _destroy state available policy_type_id zip_code_blacklist],
          carrier_agency_policy_types_attributes: [
            :id,
            :_destroy,
            :policy_type_id,
            commission_strategy_attributes: [
              :percentage
            ]
          ]
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
