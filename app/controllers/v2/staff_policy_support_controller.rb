##
# V2 StaffSuperAdmin Controller
# File: app/controllers/v2/staff_policy_support.rb

module V2
  class StaffPolicySupportController < V2Controller

    before_action :authenticate_staff!
    before_action :is_policy_support?

    private
    def is_policy_support?
      render json: { error: "Unauthorized access"}, status: :unauthorized unless current_staff.policy_support?
    end

    def view_path
      super + "/staff_policy_support"
    end

    def access_model(model_class, model_id = nil)
      model_class.send(*(model_id.nil? ? [:itself] : [:find, model_id]))
    end

  end
end
