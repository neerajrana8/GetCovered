module Carriers
  module CommissionsMethods
    extend ActiveSupport::Concern

    def add_commissions
      commission_strategy = CommissionStrategy.new(commission_params)
      if commission_strategy.save
        render json: { message: 'Commission was successfully added' }, status: :ok
      else
        render json: { message: 'Commission was not created' }, status: :unprocessable_entity
      end
    end

    def update_commission
      commission = CommissionStrategy.find(params[:commission_id])
      if commission.update(commission_params)
        render json: { message: 'Commission was successfully updated' }, status: :ok
      else
        render json: { message: 'Commission was not updated' }, status: :unprocessable_entity
      end
    end

    def commission_list
      if params[:carrier_agency_id].present?
        commissions = paginator(CommissionStrategy.where(carrier_id: params[:id], commissionable_id: params[:carrier_agency_id]).order(created_at: :desc))
        render json: commissions, status: :ok
      else
        commissions = paginator(CommissionStrategy.where(carrier_id: params[:id]).order(created_at: :desc))
        render json: commissions, status: :ok
      end
    end

    def commission
      if params[:commission_id].present?
        commission = CommissionStrategy.find(params[:commission_id])
        render json: commission, status: :ok
      else
        render json: { message: 'Something went wrong' }, status: :unprocessable_entity
      end
    end

    private

    def commission_params
      params.permit(:title, :amount,
                    :type, :fulfillment_schedule,
                    :amortize, :per_payment,
                    :enabled, :locked, :house_override,
                    :override_type, :carrier_id,
                    :policy_type_id, :commissionable_type,
                    :commissionable_id, :percentage,
                    :commission_strategy_id)
    end
  end
end
