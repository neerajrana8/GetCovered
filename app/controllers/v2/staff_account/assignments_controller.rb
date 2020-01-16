##
# V2 StaffAccount Assignments Controller
# File: app/controllers/v2/staff_account/assignments_controller.rb

module V2
  module StaffAccount
    class AssignmentsController < StaffAccountController
      
      before_action :set_assignment, only: %i[update destroy show]
            
      def index
        super(:@assignments, current_staff.assignments.communities)
      end
      
      def show; end
      
      def create
        if create_allowed?
          @assignment = Assignment.new(create_params)
          if @assignment.errors.none? && @assignment.save
            render :show,
              status: :created
          else
            render json: @assignment.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @assignment.update(update_params)
            render :show,
              status: :ok
          else
            render json: @assignment.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      def destroy
        if destroy_allowed?
          if @assignment.destroy
            render json: { success: true },
                   status: :ok
          else
            render json: { success: false },
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end
      
      
      private
      
      def view_path
        super + '/assignments'
      end
        
      def create_allowed?
        true
      end
        
      def update_allowed?
        true
      end
        
      def destroy_allowed?
        true
      end
        
      def set_assignment
        @assignment = Assignment.communities.find_by(id: params[:id])
      end
                
      def create_params
        return({}) if params[:assignment].blank?

        to_return = params.require(:assignment).permit(
          :assignable_id, :assignable_type, :primary, :staff_id
        )
        to_return
      end
        
      def update_params
        return({}) if params[:assignment].blank?

        params.require(:assignment).permit(
          :assignable_id, :assignable_type, :primary, :staff_id
        )
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def supported_orders
        supported_filters(true)
      end
        
    end
  end # module StaffAccount
end
