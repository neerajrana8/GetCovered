##
# V2 StaffAgency Controller
# File: app/controllers/v2/staff_agency_controller.rb_controller.rb

module V2
  class StaffAgencyController < V1Controller
    
    before_action :authenticate_staff!
    
    private

      def view_path
        super + "/staff_agency"
      end
      
      def access_model(model_class, model_id = nil)
        return current_staff.organizable if model_class == ::Agency && model_id == current_staff.organizable_id
        return current_staff.organizable.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
      end
      
  end
end
