##
# V2 User Payments Controller
# File: app/controllers/v2/user/payments_controller.rb

module V2
  module User
    class PaymentsController < UserController

      before_action :set_payment,
        only: [:show]

      before_action :set_substrate,
        only: [:create, :index]

      def index
        if params[:short]
          super(:@payments, @substrate)
        else
          super(:@payments, @substrate)
        end
      end

      def show
      end

      def create
        if create_allowed?
          @payment = @substrate.new(create_params)
          if !@payment.errors.any? && @payment.save_as(current_user)
            render :show,
              status: :created
          else
            render json: @payment.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: [I18n.t('user_users_controler.unauthorized_access')] },
            status: :unauthorized
        end
      end


      private

        def view_path
          super + "/payments"
        end

        def create_allowed?
          true
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

        def create_params
          return({}) if params[:payment].blank?
          to_return = {}
          return(to_return)
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
  end # module User
end
