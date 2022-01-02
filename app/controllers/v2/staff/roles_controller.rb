module V2
  module Staff
    class RolesController < StaffController

      def update
        if current_staff.staff_roles.where(id: params[:id]).count > 0
          current_staff.current_role.update(primary: false)
          current_staff.staff_roles.find(params[:id]).update(primary: true)
        end

        render json: {
          status: true
        }, status: :ok
      end

    end
  end
end