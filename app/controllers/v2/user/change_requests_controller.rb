##
# V2 User Change Requests Controller
# File: app/controllers/v2/user/change_requests_controller.rb

module V2
  module User
    class ChangeRequestsController < UserController
      before_action :set_substrate,
        only: %i[create]

      def index
        @change_requests = ChangeRequest.order(created_at: :desc) || []
        render json: @change_requests, status: :ok
      end

      def show; end

      def create
        @change_request = @substrate.new(change_request_params)
        @claim.policy_type
        if @change_request.errors.none? && @change_request.save
          render json: @change_request, status: :created
        else
          render json: @change_request.errors,
                 status: :unprocessable_entity
        end
      end

      private

      def view_path
        super + '/change_requests'
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::ChangeRequest)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.change_requests
        end
      end

      def change_request_params
        return({}) if params[:change_request].blank?

        to_return = params.require(:change_request).permit(
          :reason, :action, :method, :field, :current_value,
          :new_value, :status, :status_changed_on, :staff_id
        )
        to_return
      end
    end
  end
end
