##
# V2 StaffAgency Assignments Controller
# File: app/controllers/v2/staff_agency/assignments_controller.rb

module V2
  module StaffAgency
    class AssignmentsController < StaffAgencyController
      
      before_action :set_assignment,
        only: [:update, :destroy, :show]
      
      before_action :set_substrate,
        only: [:create, :index]
      
      def index
        if params[:short]
          super(:@assignments, @substrate)
        else
          super(:@assignments, @substrate)
        end
      end
      
      def show
      end
      
      def create
        if create_allowed?
          @assignment = @substrate.new(create_params)
          if !@assignment.errors.any? && @assignment.save
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
          super + "/assignments"
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
          @assignment = access_model(::Assignment, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Assignment)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.assignments
          end
        end
        
        def create_params
          return({}) if params[:assignment].blank?
          to_return = params.require(:assignment).permit(
            :assignable_id, :assignable_type, :primary, :staff_id
          )
          return(to_return)
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
  end # module StaffAgency
end
