##
# V2 StaffAgency CarrierAgencyAuthorizations Controller
# File: app/controllers/v2/staff_agency/carrier_agency_authorizations_controller.rb

module V2
  module StaffAgency
    class CarrierAgencyAuthorizationsController < StaffAgencyController
      
      before_action :set_carrier_agency_authorization,
        only: [:update, :show]
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@carrier_agency_authorizations, @substrate)
        else
          super(:@carrier_agency_authorizations, @substrate)
        end
      end
      
      def show
      end
      
      def update
        if update_allowed?
          if @carrier_agency_authorization.update(update_params)
            render :show,
              status: :ok
          else
            render json: @carrier_agency_authorization.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/carrier_agency_authorizations"
        end
        
        def update_allowed?
          true
        end
        
        def set_carrier_agency_authorization
          @carrier_agency_authorization = access_model(::CarrierAgencyAuthorization, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::CarrierAgencyAuthorization)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.carrier_agency_authorizations
          end
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
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffAgency
end
