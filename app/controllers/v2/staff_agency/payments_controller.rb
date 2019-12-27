##
# V2 StaffAgency Payments Controller
# File: app/controllers/v2/staff_agency/payments_controller.rb

module V2
  module StaffAgency
    class PaymentsController < StaffAgencyController
      
      before_action :set_payment, only: [:show]
            
      def index
        super(:@payments, current_staff.organizable.payments)
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
            id: [ :scalar, :array ],
            status: [:scalar, :array],
            amount:  [:scalar, :array, :interval],
            created_at: [:scalar, :array, :interval],
            updated_at: [:scalar, :array, :interval],
            invoice_id: [:scalar, :array],
            invoice: {
              id: [:scalar, :array],
              due_date: [:scalar, :array, :interval],
              policy_id: [:scalar, :array],
              user_id: [:scalar, :array],
              policy: {
                id: [:scalar, :array],
                number: [:scalar, :array],
                account_id: [:scalar, :array]
              },
              user: {
                id: [:scalar, :array],
                profile: {
                  first_name: [:scalar],
                  last_name: [:scalar],
                  full_name: [:scalar]
                }
              }
            }
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffAgency
end
