##
# V1 Account Payments Controller
# file: app/controllers/v1/account/payments_controller.rb

module V1
  module Account
    class PaymentsController < StaffController
      before_action :set_payment,
        only: :show

      def index
        if params[:short]
          super(:@payments, @account.payments)
        else
          super(:@payments, @account.payments, :policy, user: :profile)
        end
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
            amount_refunded: [:scalar, :array, :interval],
            user_in_system: [:scalar],
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
                policy_number: [:scalar, :array],
                account_id: [:scalar, :array]
              },
              user: {
                id: [:scalar, :array],
                guest: [:scalar],
                profile: {
                  first_name: [:scalar],
                  last_name: [:scalar]
                }
              }
            }
          }
        end

        def set_payment
          @payment = @account.payments.find(params[:id])
        end

    end
  end
end
