##
# V1 Account Staffs Controller
# file: app/controllers/v1/account/staffs_controller.rb

module V1
  module Account
    class StaffsController < StaffController
      before_action :set_staff,
        only: [:show, :update, :create_assignment, :delete_assignment]

      def index
        super(:@staffs, @account.staffs, :profile)
      end

      def show
      end

      def new
      end

      def create
        if staff_params[:email] && Staff.where(email: staff_params[:email]).count > 0
          render json: { error: 'email has already been taken' },
            status: :unprocessable_entity
          return
        end
        @staff = @account.staffs.invite!(staff_params)
        if @staff.save
          render :show, status: :created
        else
          render json: @staff.errors,
            status: :unprocessable_entity
        end
      end

      def update
        if @staff.update_as(current_staff, staff_params)
          render :show, status: :ok
        else
          render json: @staff.errors,
            status: :unprocessable_entity
        end
      end

      def create_assignment
        assignment = @staff.assignments.new(assignment_params)
        if assignment.save
          render json: { success: true }, status: :ok
        else
          render json: { success: false, errors: assignment.errors },
            status: :unprocessable_entity
        end
      end

      def delete_assignment
        assignment = @staff.assignments.find(params[:assignment_id])
        if assignment.nil?
          render json: { success: false, errors: { id: "Assignment does not exist." } },
            status: :unprocessable_entity
        else
          assignment.delete
          render json: { success: true }, status: :ok
        end
      end

      private

        def view_path
          super + '/staffs'
        end

        def staff_params
          params.require(:staff).permit(:email, :permissions, :settings,
                                        notification_options: {},
                                        profile_attributes: [
                                          :id, :first_name, :middle_name, :last_name,
                                          :contact_email, :contact_phone, :birth_date
                                        ])
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            email: [ :scalar, :array, :like ],
            permissions: [ :scalar, :array ],
            profile: {
              first_name: [ :scalar, :like ],
              last_name: [ :scalar, :like ]
            }
          }
        end

        def assignment_params
          params.require(:assignment).permit(:staff_id, :assignable_id, :assignable_type)
        end

        def set_staff
          @staff = @account.staffs.find(params[:id])
        end
    end
  end
end
