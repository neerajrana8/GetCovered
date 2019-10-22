##
# V2 StaffSuperAdmin Controller
# File: app/controllers/v2/staff_super_admin_controller.rb_controller.rb

module V2
  class StaffSuperAdminController < V1Controller
    
    before_action :authenticate_staff!
    
    private

      def view_path
        super + "/staff_super_admin"
      end
      
      def access_model(model_class, model_id = nil)
        model_class.send(*(model_id.nil? ? [:itself] : [:find, model_id]))
      end
      
  end
end
