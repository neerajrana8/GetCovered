##
# V2 StaffAgency InsurableRates Controller
# File: app/controllers/v2/staff_agency/insurable_rates_controller.rb

module V2
  module StaffAgency
    class InsurableRatesController < StaffAgencyController
      
      before_action :set_insurable
      before_action :set_insurable_rate, only: [:update]
      
      def index
        super(:@insurable_rates, @insurable.insurable_rates)
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
      
      def refresh_rates
        @insurable.reset_qbe_rates(params[:inline], params[:fix_all])
      end

      private
      
        def view_path
          super + "/insurable_rates"
        end
        
        def update_allowed?
          true
        end

        def set_insurable
          @insurable = current_staff.organizable.insurables.find(params[:insurable_id])
        end
        
        def set_insurable_rate
          @insurable_rate = @insurable.insurable_rates.find(params[:id])
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
