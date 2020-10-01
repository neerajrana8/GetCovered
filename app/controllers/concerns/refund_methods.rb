module RefundMethods
  extend ActiveSupport::Concern

  def create
    @refund = Refund.new(refund_params)

    if @refund.save
      render :show, status: :created
    else
      render json: @refund.errors, status: :unprocessable_entity
    end
  end

  def update
    if @refund.update(refund_params)
      render :show, status: :ok
    else
      render json: @refund.errors, status: :unprocessable_entity
    end
  end

  def index
    @refunds = paginator(Refund.order(created_at: :desc))
    render json: @refunds, status: :ok
  end

  def approve
    change_request = ChangeRequest.find_by(request_id: params[:request_id])
    if change_request.update(status: 'succeeded') && change_request.status == 'succeeded'
      Stripe::Refund.create(charge: stripe_id)
      render json: { message: 'Refund was approved' }, status: :ok
    else
      render json: { message: 'Refund was not approved' }, status: :unprocessable_entity
    end
  end

  def decline
    change_request = ChangeRequest.find_by(request_id: params[:request_id])
    if change_request.update(status: 'failed') && change_request.status == 'failed'
      render json: { message: 'Refund was declined' }, status: :ok
    else
      render json: { message: 'Refund was not declined' }, status: :unprocessable_entity
    end
  end

  private

  def refund_params
    params.require(:refund)
        .permit(:stripe_id, :amount, :currency,
                :failure_reason, :stripe_reason, :receipt_number,
                :stripe_status, :status, :full_reason, :error_message,
                :amount_returned_via_dispute, :charge_id)
  end

  def set_refund
    @refund = Refund.find(params[:id])
  end
end
