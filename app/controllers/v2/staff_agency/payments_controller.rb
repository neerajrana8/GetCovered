##
# V2 StaffAgency Payments Controller
# File: app/controllers/v2/staff_agency/payments_controller.rb

module V2
  module StaffAgency
    class PaymentsController < StaffAgencyController
      
      before_action :set_payment,
        only: [:show]
      
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@payments, @substrate)
        else
          super(:@payments, @substrate)
        end
      end
      
      def show
      end
      
      
      private
      
        def view_path
          super + "/payments"
        end
        
        def set_payment
          @payment = access_model(::Payment, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Payment)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.payments
          end
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
