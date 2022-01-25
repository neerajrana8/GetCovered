module V2
  module Staff
    class RolesController < StaffController

      def update
        if current_staff.staff_roles.where(id: params[:id]).count > 0
          current_role = current_staff.current_role
          current_role.update(primary: false) if current_role
          current_staff.staff_roles.find(params[:id]).update(primary: true)
        else
          render json: {
            status: false
          }, status: :unprocessable_entity and return
        end

        render json: {
          status: true
        }, status: :ok
      end

      def index
        @roles = current_staff.staff_roles
      end

    end
  end
end