##
# V2 User Invoices Controller
# File: app/controllers/v2/user/invoices_controller.rb

module V2
  module User
    class InvoicesController < UserController
      before_action :set_invoice, only: [:show]
      before_action :set_substrate, only: [:index]

      def index
        super(:@invoices, current_user.invoices.order(created_at: :desc))
        render json: @invoices, status: :ok
      end

      def show
      end

      private

      def view_path
        super + "/invoices"
      end

      def set_invoice
        @invoice = access_model(::Invoice, params[:id])
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Invoice)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.invoices
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: [:scalar, :array],
          created_at: [:scalar, :array, :interval],
          updated_at: [:scalar, :array, :interval],
          number: [:scalar, :array],
          status: [:scalar, :array],
          external: [:scalar],
          available_date: [:scalar, :array, :interval],
          due_date: [:scalar, :array, :interval],
          
          total_due: [:scalar, :array, :interval],
          total_payable: [:scalar, :array, :interval],
          total_received: [:scalar, :array, :interval],
          
          invoiceable_id: [:scalar, :array],
          invoiceable_type: [:scalar, :array]
        }
      end

      def supported_orders
        supported_filters(true)
      end

    end
  end # module User
end
