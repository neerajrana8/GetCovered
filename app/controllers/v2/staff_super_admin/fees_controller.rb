##
# V2 StaffAgency Fees Controller
# File: app/controllers/v2/staff_agency/fees_controller.rb

module V2
  module StaffSuperAdmin
    class FeesController < StaffSuperAdminController
      before_action :set_fee, only: %i[show update]

      def index
        super_index(:fees, Fee.all)
        render template: 'v2/shared/fees/index', status: :ok
      end

      def show
        if @fee.present?
          render json: @fee, status: :ok
        else
          render json: { message: 'No fee' }
        end
      end

      def create
        @fee = Fee.new(fee_params)
        if @fee.save && @fee.errors.none?
          render json: @fee, status: :created
        else
          render json: @fee.errors, status: :unprocessable_entity
        end
      end

      def update
        if @fee.update(fee_params) && @fee.errors.none?
          render json: { message: 'Fee updated' }, status: :created
        else
          render json: @fee.errors, status: :unprocessable_entity
        end
      end

      private

      def set_fee
        @fee = Fee.find(params[:id])
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: %i[scalar array],
          amount: %i[scalar array],
          per_payment: %i[scalar array],
          amortize: %i[scalar array],
          enabled: %i[scalar array],
          assignable_type: %i[scalar array],
          assignable_id: %i[scalar array],
          ownerable_type: %i[scalar array],
          ownerable_id: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def fee_params
        require(:fee).
          permit(
            :title, :slug, :amount, :amount_type, :type,
            :per_payment, :amortize, :enabled,
            :locked, :assignable_type,
            :assignable_id, :ownerable_type,
            :ownerable_id
          )
      end
    end
  end
end
