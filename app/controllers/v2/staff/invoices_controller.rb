##
# V1 Account Invoices Controller
# file: app/controllers/v1/account/invoices_controller.rb

module V1
  module Account
    class InvoicesController < StaffController
      before_action :set_invoice,
        only: :show

      def index
        if params[:short]
          super(:@invoices, @account.invoices)
        else
          super(:@invoices, @account.invoices, :policy, user: :profile)
        end
      end

      def show
      end

      private

        def view_path
          super + '/invoices'
        end

        def supported_filters
          {
            id: [:scalar, :array],
            created_at: [:scalar, :array, :interval],
            updated_at: [:scalar, :array, :interval],
            number: [:scalar, :array],
            status: [:scalar, :array],
            due_date: [:scalar, :array, :interval],
            total: [:scalar, :array, :interval],
            subtotal: [:scalar, :array, :interval],
            tax: [:scalar, :array, :interval],
            tax_percentage: [:scalar, :array, :interval],
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
        end

        def set_invoice
          @invoice = @account.invoices.find(params[:id])
        end
    end
  end
end
