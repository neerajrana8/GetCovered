##
# V2 StaffAgency InsurableRates Controller
# File: app/controllers/v2/staff_agency/insurable_rates_controller.rb

module V2
  module StaffAgency
    class InsurableRatesController < StaffAgencyController
      
      before_action :set_insurable_rate,
        only: [:update]
            
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@insurable_rates, @substrate)
        else
          super(:@insurable_rates, @substrate)
        end
      end
      
      def update
        if update_allowed?
          if @insurable_rate.update(update_params)
            render json: { success: true },
              status: :ok
          else
            render json: @insurable_rate.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def access_model
        model_class
      end
      
      
      private
      
        def view_path
          super + "/insurable_rates"
        end
        
        def update_allowed?
          true
        end
        
        def set_insurable_rate
          @insurable_rate = access_model(::InsurableRate, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::InsurableRate)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.insurable_rates
          end
        end
        
        def update_params
          return({}) if params[:insurable_rate].blank?
          params.require(:insurable_rate).permit(
            :activated
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
