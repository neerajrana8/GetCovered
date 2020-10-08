module PolicyCancellationRequestsMethods
  extend ActiveSupport::Concern

  def index
    @change_requests = paginator(relation)
    render json: @change_requests, status: :ok
  end

  def show
    render json: @change_request, status: :ok
  end

  def approve
    @change_request.changeable.cancel('manual_cancellation_with_refunds')
    @change_request.update(status: :approved)
    render json: @change_request, status: :ok
  end

  def cancel
    @change_request.changeable.cancel('manual_cancellation_without_refunds')
    @change_request.update(status: :approved)
    render json: @change_request, status: :ok
  end

  def decline
    @change_request.update(status: :declined)
    render json: @change_request, status: :ok
  end

  private

  def set_change_request
    @change_request = relation.find(params[:id])
  end

  included do
    before_action :set_change_request, only: %i[show approve decline cancel]
  end
end
