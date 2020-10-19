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
    policy = @change_request.changeable
    policy.cancel('manual_cancellation_with_refunds', @change_request.created_at.to_date)
    @change_request.update(status: :approved)
    Policies::CancellationMailer.
      with(policy: policy, change_request: @change_request).
      cancel_confirmation.
      deliver_later
    render template: 'v2/shared/change_requests/show', status: :ok
  end

  def cancel
    policy = @change_request.changeable
    policy.cancel('manual_cancellation_without_refunds', @change_request.created_at.to_date)
    @change_request.update(status: :approved)
    Policies::CancellationMailer.
      with(policy: policy, change_request: @change_request).
      cancel_confirmation.
      deliver_later
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

  def relation
    result =
      ChangeRequest.
        joins('INNER JOIN policies ON (change_requests.changeable_id = policies.id AND change_requests.changeable_type = \'Policy\')').
        order(created_at: :desc)
    actions =
      if params[:customized_action].present?
        params[:customized_action]
      else
        %w[cancel refund]
      end
    result.where(change_requests: { customized_action: actions })
  end

  included do
    before_action :set_change_request, only: %i[show approve decline cancel]
  end
end
