##
# V1 User Invoices Controller
# file: app/controllers/v1/user/invoices_controller.rb

module V2
  module User
    class InvoicesController < UserController
      before_action :set_invoice,
        only: [:show, :preview, :pay]

      def index
        if params[:short]
          super(:@invoices, current_user.invoices)
        else
          super(:@invoices, current_user.invoices, :policy)
        end
      end

      def show
      end

      def preview

        # kick out liars and thieves
        if @invoice.status != 'available'
          render json: { invoice: "has status '#{@invoice.status}' and is not eligible for payment" },
            status: :unprocessable_entity
          return
        end

        # set payment method
        current_payment_method = params[:payment_method]
        if current_payment_method.nil?
          current_payment_method = @invoice.user.current_payment_method
          current_payment_method = 'bank_account' if current_payment_method != 'card'
        end
        if current_payment_method != 'card' && current_payment_method != 'bank_account'
          render json: { payment_method: "must be a card or a verified bank account" },
            status: :unprocessable_entity
          return
        end

        # create preview (and set total)
        preview_data = @invoice.calculate_total(current_payment_method)
        render json: { success: true, preview: preview_data },
          status: :ok
      end

      def pay

        # kick out liars and thieves
        if @invoice.status != 'available'
          render json: { invoice: "has status '#{@invoice.status}' and is not eligible for payment" },
            status: :unprocessable_entity
          return
        end

        # determine the type of the provided payment method
        current_payment_id = nil
        current_payment_id_type = nil
        current_payment_method = nil
        if params[:stripe_token].nil?
          current_payment_method = @invoice.user.current_payment_method
          current_payment_method = 'bank_account' if current_payment_method == 'ach_verified'
        elsif params[:stripe_token].start_with("src_")
          ssource = nil
          begin
            ssource = Stripe::Source.retrieve(params[:stripe_token])
          rescue Stripe::StripeError => e
            render json: { invoice: "payment failed; payment processor returned error '#{e.message}'" },
              status: :unprocessable_entity
            return
          end
          current_payment_id = params[:stripe_token]
          current_payment_id_type = :stripe_source
          current_payment_method = ssource['type']  # MOOSE WARNING: only cards are possible since this won't be a verified bank account and the ach_credit_transfer and ach_debit source types are not supported here right now
        elsif params[:stripe_token].start_with("tok_")
          token = nil
          begin
            token = Stripe::Token.retrieve(params[:stripe_token])
          rescue Stripe::StripeError => e
            render json: { invoice: "payment failed; payment processor returned error '#{e.message}'" },
              status: :unprocessable_entity
            return
          end
          current_payment_id = params[:stripe_token]
          current_payment_id_type = :stripe_token
          current_payment_method = token['type']
        end

        # validate payment method and recalculate total
        if current_payment_method != 'card' && current_payment_method != 'bank_account'
          render json: { payment_method: "must be a card or a verified bank account" },
            status: :unprocessable_entity
          return
        end
        receipt_data = @invoice.calculate_total(current_payment_method)

        # validate amount and attempt payment
        if params[:amount].nil? || params[:amount] != receipt_data['total']
          render json: { amount: "must match invoice total" },
            status: :unprocessable_entity
        else
          pay_response = {}
          if current_payment_id_type.nil?
            pay_response = @invoice.pay(amount_override: receipt_data['total']) # why the override? just in case some other thread has recalculated invoice.total with a different payment method after we did
          else
            pay_response = @invoice.pay(amount_override: receipt_data['total'], current_payment_id_type => current_payment_id) # why the override? just in case some other thread has recalculated invoice.total with a different payment method after we did
          end
          @invoice.reload
          if pay_response[:success]
            render json: { success: true, receipt: receipt_data, charge_id: pay_response[:charge_id], charge_status: pay_response[:charge_status], invoice_status: @invoice.status },
              status: :ok
          else
            render json: { invoice: "payment failed: #{pay_response[:error] || 'unknown error'}" },
              status: :unprocessable_entity
          end
        end
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
            policy_id: [:scalar, :array],
            user_id: [:scalar, :array],
            policy: {
              id: [:scalar, :array],
              policy_number: [:scalar, :array]
            },
            available_date: [:scalar, :array, :interval]
          }
        end

        def fixed_filters
          { 'available_date' => { 'end' => Time.current.to_date.to_s } }
        end

        def set_invoice
          @invoice = current_user.invoices.find(params[:id])
          @invoice = nil if !@invoice.nil? && @invoice.available_date > Time.current.to_date
        end
    end
  end
end
