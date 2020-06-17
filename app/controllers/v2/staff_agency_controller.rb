##
# V2 StaffAgency Controller
# File: app/controllers/v2/staff_agency_controller.rb

module V2
  class StaffAgencyController < V2Controller
    
    before_action :authenticate_staff!
    before_action :is_agent?

    private

      def is_agent?
        render json: { error: "Unauthorized access"}, status: :unauthorized unless current_staff.agent?
      end

      def view_path
        super + "/staff_agency"
      end
      
      def access_model(model_class, model_id = nil)
        return current_staff.organizable if model_class == ::Agency && model_id&.to_i == current_staff.organizable_id
        return current_staff.organizable.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
      end
      
  end
end
