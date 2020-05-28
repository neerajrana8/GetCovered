##
# V2 StaffAgency Fees Controller
# File: app/controllers/v2/staff_agency/fees_controller.rb

module V2
  module StaffAgency
    class FeesController < StaffAgencyController
      
      before_action :set_agency,
        only: [:create, :update]

      before_action :set_assignment,
        only: [:create, :update]
      
      def index
        @fees = Fee.all || []
        if @fees.empty?
          render json: { message: 'No fees' }
        else
          render json: @fees, status: :ok
        end
      end
      
      def show
        @fee = Fee.find(params[:id])
        if @fee.present?
          render json: @fee, status: :ok
        else
          render json: { message: 'No fee' }
        end
      end

      def update
        if create_allowed?
          assignment = @staff.assignments.take
          @fee = Fee.find(params[:id])
          if @fee.update(fee_params.merge(ownerable: @agency, assignable: assignment)) && !@fee.errors.any?
            render json: { message: 'Fee updated' },
              status: :created
          else
            render json: @fee.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def create
        if create_allowed?
          assignment = @staff.assignments.take
          @fee = Fee.new(fee_params.merge(ownerable: @agency, assignable: assignment))
          if @fee.save && !@fee.errors.any?
            render json: @fee,
              status: :created
          else
            render json: @fee.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end

      private

      def fee_params
        require(:fee).permit(:title, :slug,
                             :amount, :amount_type, :type,
                             :per_payment, :amortize, :enabled,
                             :locked, :assignable_type,
                             :assignable_id, :ownerable_type,
                             :ownerable_id
                            )
      end
        
      def create_allowed?
        true
      end

      def set_staff
        @staff = Staff.find(params[:id])
      end

      def set_agency
        @agency = Agency.find(@staff.id)
      end
        
    end
  end # module StaffAgency
end
