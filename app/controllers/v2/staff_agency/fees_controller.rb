module V2
  module StaffAgency
    class FeesController < StaffAgencyController
      before_action :set_fee, only: %i[show update]
      before_action :validate_assignable, only: %i[create update]
      before_action :set_ownerable, only: %i[create update]
      before_action :validate_ownerable, only: %i[create update]

      def index
        super(:fees, Fee.all)
        render template: 'v2/shared/fees/index', status: :ok
      end

      def show
        render json: @fee, status: :ok
      end

      def create
        @fee = Fee.new(fee_params.merge(ownerable_id: @ownerable.id, ownerable_type: @ownerable.class.to_s))
        if @fee.save && @fee.errors.none?
          render json: @fee, status: :created
        else
          render json: @fee.errors, status: :unprocessable_entity
        end
      end

      def update
        if @fee.update(fee_params.merge(ownerable_id: @ownerable.id, ownerable_type: @ownerable.class.to_s)) &&
           @fee.errors.none?
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

      def set_ownerable
        @ownerable =
          case params[:assignable_type]
          when 'CarrierAgencyAuthorization'
            CarrierAgencyAuthorization.find(params[:assignable_id]).agency
          when 'BillingStrategy'
            BillingStrategy.find(params[:assignable_id]).agency
          end
      end

      def validate_ownerable
        if @ownerable.agency != @agency
          render json: standard_error(:bad_ownerable, 'Assignable should be in the same agency like an agent'),
                 status: 422
        end
      end

      def validate_assignable
        unless params[:assignable_type].present? &&
               %w[CarrierAgencyAuthorization BillingStrategy].include?(params[:assignable_type]) &&
               params[:assignable_id].present? &&
               params[:assignable_type].constantize.find(params[:assignable_id])
          render(json: standard_error(:bad_assignable, 'Bad assignable'), status: 422)
        end
      end
    end
  end
end
