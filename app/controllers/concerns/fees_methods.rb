module FeesMethods
  extend ActiveSupport::Concern

  included do
    before_action :set_fee_assignable, only: %i[add_fee fees destroy_fee]
    before_action :set_fee_owner, only: [:add_fee]

    def add_fee
      @fee = Fee.create(fee_params.merge(ownerable: @fee_owner, assignable: @fee_assignable))
      if @fee.errors.blank?
        render template: 'v2/shared/fees/show', status: :ok
      else
        render json: standard_error(:fee_was_not_created, nil, @fee.errors.full_messages),
               status: :unprocessable_entity
      end
    end

    def fees
      @fees = paginator(@fee_assignable.fees)
      render template: 'v2/shared/fees/index', status: :ok
    end

    def destroy_fee
      @fee = @fee_assignable.fees.find(params[:fee_id])
      if PolicyPremiumFee.where(fee: @fee).any? || @fee.locked?
        render json: standard_error(:fee_cant_be_destroyed, 'Fee cant be destroyed'),
               status: :unprocessable_entity
      else
        @fee.destroy
        if @fee.errors.any?
          render json: standard_error(:fee_was_not_destroyed, nil, @fee.errors.full_messages),
                 status: :unprocessable_entity
        else
          head :no_content
        end
      end
    end

    private

    def fee_params
      params.require(:fee).permit(
        :title, :slug,
        :amount, :amount_type, :type,
        :per_payment, :amortize, :enabled,
        :locked
      )
    end
  end
end
