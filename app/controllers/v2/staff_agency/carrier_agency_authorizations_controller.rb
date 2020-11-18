##
# V2 StaffAgency CarrierAgencyAuthorizations Controller
# File: app/controllers/v2/staff_agency/carrier_agency_authorizations_controller.rb

module V2
  module StaffAgency
    class CarrierAgencyAuthorizationsController < StaffAgencyController
      
      before_action :set_carrier_agency_authorization, only: %i[update show add_fee fees destroy_fee]
      before_action :set_substrate, only: [:index]

      # included after before_action :set_substrate because we should initialize substrate before module's callbacks
      include FeesMethods
      
      def index
        super(:@carrier_agency_authorizations, @substrate)
        render template: 'v2/shared/carrier_agency_authorizations/index', status: :ok
      end
      
      def show
        render template: 'v2/shared/carrier_agency_authorizations/show', status: :ok
      end
      
      def update
        if @carrier_agency_authorization.update(update_params)
          render template: 'v2/shared/carrier_agency_authorizations/show', status: :ok
        else
          render json: standard_error(:update_error, nil, @carrier_agency_authorization.errors),
                 status: :unprocessable_entity
        end
      end
      
      private
      
      def view_path
        super + '/carrier_agency_authorizations'
      end
        
      def set_carrier_agency_authorization
        @carrier_agency_authorization = access_model(::CarrierAgencyAuthorization, params[:id])
      end
        
      def set_substrate
        @substrate =
          CarrierAgencyAuthorization.joins(:carrier_agency).where(carrier_agencies: { agency_id: @agency.id })
      end
        
      def update_params
        return({}) if params[:carrier_agency_authorization].blank?

        params.require(:carrier_agency_authorization).permit(
          :available, zip_code_blacklist: {}
        )
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          policy_type_id: %i[scalar array],
          state: %i[scalar array],
          available: %i[scalar],
          carrier_agency_id: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def set_fee_owner
        @fee_owner = @carrier_agency_authorization.agency
      end

      def set_fee_assignable
        @fee_assignable = @carrier_agency_authorization
      end
    end
  end # module StaffAgency
end
