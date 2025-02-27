##
# V2 StaffAccount Controller
# File: app/controllers/v2/staff_account_controller.rb_controller.rb

module V2
  class StaffAccountController < V1Controller
    
    before_action :authenticate_staff!
    
    private

      def view_path
        super + "/staff_account"
      end
      
      def access_model(model_class, model_id = nil)
        return current_staff.organizable if model_class == ::Account && model_id == current_staff.organizable_id
        return current_staff.organizable.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
      end
      
  end
end
