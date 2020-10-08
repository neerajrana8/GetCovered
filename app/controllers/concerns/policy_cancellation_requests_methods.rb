module PolicyCancellationRequestsMethods
  extend ActiveSupport::Concern

  def index
    @change_requests = paginator(relation)
    render template: 'v2/shared/change_requests/index', status: :ok
  end

  def show
    render template: 'v2/shared/change_requests/show', status: :ok
  end

  def approve
    policy.cancel('manual_cancellation_with_refunds', @change_request.created_at)
    @change_request.update(status: :approved)
    render template: 'v2/shared/change_requests/show', status: :ok
  end

  def cancel
    policy = @change_request.changeable
    policy.cancel('manual_cancellation_without_refunds', @change_request.created_at)
    @change_request.update(status: :approved)
    render template: 'v2/shared/change_requests/show', status: :ok
  end

  def decline
    @change_request.update(status: :declined)
    render template: 'v2/shared/change_requests/show', status: :ok
  end

  private

  def set_change_request
    @change_request = relation.find(params[:id])
  end

  included do
    before_action :set_change_request, only: %i[show approve decline cancel]
  end
end
