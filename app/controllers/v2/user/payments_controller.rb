##
# V1 User Payments Controller
# file: app/controllers/v1/user/payments_controller.rb

module V1
  module User
    class PaymentsController < UserController
      before_action :set_payment,
        only: :show

      def index
        super(:@payments, current_user.payments)
      end

      def show
      end

      private

        def view_path
          super + '/payments'
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            status: [:scalar, :array],
            amount:  [:scalar, :array, :interval],
            user_in_system: [:scalar],
            policy_id: [:scalar, :array],
            user_id: [:scalar, :array]
          }
        end

        def set_payment
          @payment = current_user.payments.find(params[:id])
        end
    end
  end
end
