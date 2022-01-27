##
# V2 StaffAccount Controller
# File: app/controllers/v2/staff_account_controller.rb

module V2
  class StaffAccountController < V2Controller
    
    before_action :authenticate_staff!
    before_action :is_staff?
    before_action :set_account

    private

    def is_staff?
      render json: { error: "Unauthorized access"}, status: :unauthorized unless current_staff.current_role(organizable: 'Account').staff?
    end

    def view_path
      super + "/staff_account"
    end

    def access_model(model_class, model_id = nil)
      return current_staff.current_role(organizable: 'Account').organizable if model_class == ::Account && model_id&.to_i == current_staff.current_role(organizable: 'Account').organizable_id
      return current_staff.current_role(organizable: 'Account').organizable.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
    end

    def set_account
      @account =
        if current_staff.current_role(organizable: 'Account').present? && current_staff.current_role(organizable: 'Account').organizable.is_a?(::Account)
          current_staff.current_role(organizable: 'Account').organizable
        end
    end
  end
end
