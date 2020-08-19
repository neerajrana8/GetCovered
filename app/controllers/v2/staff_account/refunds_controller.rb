##
# V2 StaffAccount Refunds Controller
# File: app/controllers/v2/staff_account/refunds_controller.rb

module V2
  module StaffAccount
    class RefundsController < StaffAccountController
      before_action :set_refund, only: [:approve, :decline]
      
      def index
        @refunds = paginator(Refund.order(created_at: :desc))
        render json: @refunds, status: :ok
      end
      
      def approve
        change_request = ChangeRequest.find_by(request_id: params[:request_id])
        if change_request.update(status: 'succeeded') && change_request.status == 'succeeded'
          Stripe::Refund.create({
            charge: stripe_id
          })
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
      def set_refund
        @refund = Refund.find(params[:id])
      end
    end
  end
end
