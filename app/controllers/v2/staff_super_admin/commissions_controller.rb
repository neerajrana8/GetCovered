##
# V2 StaffAgency Commissions Controller
# File: app/controllers/v2/staff_agency/commissions_controller.rb

module V2
  module StaffSuperAdmin
    class CommissionsController < StaffSuperAdminController
      
      before_action :set_commission, only: %i[show update separate_for_approval]
      
      def index
        super(:@commissions, Commission.all)
      end
      
      def show
      end

      def update
        if update_allowed?
          if @commission.update(update_params)
            render :show, status: :ok
          else
            render json: @commission.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end
      
      def separate_for_approval
        result = params[:commission_item_ids].blank? ? @commission.separate_for_approval : @commission.separate_for_approval(@commission.commission_items.where(id: params[:commission_item_ids].map{|cid| cid.to_i }))
        if result[:success]
          render json: {
            success: true,
            created_commission_id: result[:commission].id
          }, status: :ok
        else
          render json: standard_error(:separation_failed, result[:error]),
            status: 422
        end
      end

      def approve
        result = @commission.approve(current_staff, with_payout_method: params.permit(:payout_method)&.[](:payout_method))
        if result[:success]
          render json: { success: true }, status: :ok
        else
          render json: standard_error(:approval_failed, result[:error]),
            status: 422
        end
      end
      
      def mark_paid
        result = @commission.mark_paid(current_staff, with_payout_data: mark_paid_params[:data], with_payout_notes: mark_paid_params[:notes])
        if result[:success]
          render json: { success: true }, status: :ok
        else
          render json: standard_error(:payment_failed, result[:error]),
            status: 422
        end
      end
      
      def pay_with_stripe
        result = @commission.pay_with_stripe(current_staff, with_payout_data: pay_with_stripe_params[:data], with_payout_notes: pay_with_stripe_params[:notes])
        if result[:success]
          render json: { success: true }, status: :ok
        else
          render json: standard_error(:payment_failed, result[:error]),
            status: 422
        end
      end
      
      private
      
      def view_path
        super + '/commissions'
      end

      def update_allowed?
        false #current_staff.super_admin?
      end

      def update_params
        nil # no update permitted params.require(:commission).permit()
      end
        
      def set_commission
        @commission = Commission.find(params[:id])
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          commissionable_type: [ :scalar, :array ],
          commissionable_id: [ :scalar, :array ],
        }
      end

      def supported_orders
        supported_filters(true)
      end
      
      def mark_paid_params
        params.permit(:data, :notes)
      end
      
      def pay_with_stripe_params
        params.permit(:data, :notes)
      end
        
    end
  end # module StaffAgency
end
