##
# V2 StaffAgency Commissions Controller
# File: app/controllers/v2/staff_agency/commissions_controller.rb

module V2
  module StaffSuperAdmin
    class CommissionsController < StaffSuperAdminController
      
      before_action :set_commission, only: %i[show update approve destroy]
      
      def index
        super(:@commissions, Commission.all)
      end
      
      def show; end

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

      def approve
        @policy.approve
        render json: { message: 'Commission Payout is scheduled' }, status: :ok
      end
      
      private
      
      def view_path
        super + '/commissions'
      end

      def update_allowed?
        current_staff.super_admin?
      end

      def update_params
        params.require(:commission).permit(:amount, :distributes)
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
        
    end
  end # module StaffAgency
end