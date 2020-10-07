##
# V2 StaffAgency Change Requests Controller
# File: app/controllers/v2/staff_agency/change_requests_controller.rb

module V2
  module StaffAgency
    class PolicyCancellationRequestsController < StaffAgencyController
      before_action :set_change_request, only: %i[show approve decline]

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
      end

      def decline
        @change_request.update(status: :declined)
      end

      private

      def set_change_request
        @change_request = relation.find(params[:id])
      end

      def relation
        ChangeRequest.
          joins('INNER JOIN policies ON (change_requests.changeable_id == policies.id AND change_requests.changeable_type = "Policy"').
          where(customized_action: 'cancel').
          order(created_at: :desc)
      end
    end
  end
end
