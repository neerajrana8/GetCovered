##
# V1 User Charges Controller
# file: app/controllers/v1/user/charges_controller.rb

module V1
  module User
    class ChargesController < UserController
      before_action :set_charge, only: :show

      def index
        super(:@charges, current_user.charges)
      end

      def show
      end

      private

        def view_path
          super + '/charges'
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            created_at: [:scalar, :array, :interval],
            updated_at: [:scalar, :array, :interval],
            status: [:scalar, :array],
            payment_method: [:scalar, :array],
            amount: [:scalar, :array, :interval],
            invoice_id: [:scalar, :array],
            invoice: {
              id: [:scalar, :array],
              created_at: [:scalar, :array, :interval],
              updated_at: [:scalar, :array, :interval],
              number: [:scalar, :array],
              status: [:scalar, :array],
              due_date: [:scalar, :array, :interval],
              total: [:scalar, :array, :interval],
              subtotal: [:scalar, :array, :interval],
              policy_id: [:scalar, :array],
              policy: {
                id: [:scalar, :array],
                policy_number: [:scalar, :array]
              }
            }
          }
        end

        def set_charge
          @charge = current_user.charges.find(params[:id])
        end
    end
  end
end
