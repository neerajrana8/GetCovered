##
# V2 StaffAgency InsurableRates Controller
# File: app/controllers/v2/staff_agency/insurable_rates_controller.rb

module V2
  module StaffSuperAdmin
    class InsurableRatesController < StaffSuperAdminController

      before_action :set_agency
      before_action :set_insurable
      before_action :set_insurable_rate, only: [:update]

      def index
	      @rates = {}

	      @rates["coverage_c"] = @insurable.insurable_rates
		  										 							 .coverage_c
													 							 .activated

		  	@rates["liability"] = @insurable.insurable_rates
									  										.liability
									  									  .activated

		  	@rates["optional"] = @insurable.insurable_rates
 	  							  									 .optional
  								  									 .activated
								  										 .where.not(sub_schedule: "policy_fee")

	      render json: @rates.to_json,
	             status: :ok
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
        @insurable.reset_qbe_rates(true, false)
      end

      private

        def view_path
          super + "/insurable_rates"
        end

        def update_allowed?
          true
        end

        def set_insurable
          @insurable = @agency.insurables.find(params[:insurable_id])
        end

        def set_agency
          @agency = Agency.find(params[:agency_id])
        end

        def set_insurable_rate
          @insurable_rate = @insurable.insurable_rates.find(params[:id])
        end

        def update_params
          params.require(:insurable_rate).permit(:enabled, :mandatory)
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
