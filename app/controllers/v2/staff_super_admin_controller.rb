##
# V2 StaffSuperAdmin Controller
# File: app/controllers/v2/staff_super_admin_controller.rb

module V2
  class StaffSuperAdminController < V2Controller
    
    before_action :authenticate_staff!
    before_action :is_super_admin?

    private
      def is_super_admin?
        render json: { error: "Unauthorized access"}, status: :unauthorized unless current_staff.staff_roles.where(role: 'super_admin').count > 0
      end

      def view_path
        super + "/staff_super_admin"
      end
      
      def access_model(model_class, model_id = nil)
        model_class.send(*(model_id.nil? ? [:itself] : [:find, model_id]))
      end
      
  end
end
