module V2
  module Staff
    class RefundsController < StaffController
      before_action :only_super_admins, except: [:index, :show]
      before_action :set_refund, only: [:show, :update, :destroy]
      
      def index
        @refunds = Refund.all
      end
      
      def show
      end
      
      def create
        @refund = Refund.new(refund_params)
        
        if @refund.save
          render :show, status: :created, location: @refund
        else
          render json: @refund.errors, status: :unprocessable_entity
        end
      end
      
      def update
        if @refund.update(refund_params)
          render :show, status: :ok, location: @refund
        else
          render json: @refund.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @refund.destroy
      end
      
      private
      def set_refund
        @refund = Refund.find(params[:id])
      end
      
      def refund_params
        params.require(:refund)
              .permit(:stripe_id, :amount, :currency,
                      :failure_reason, :stripe_reason, :receipt_number,
                      :stripe_status, :status, :full_reason, :error_message,
                      :amount_returned_via_dispute, :charge_id)
      end
    end
  end
end
