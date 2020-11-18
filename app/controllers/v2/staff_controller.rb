module V2
  class StaffController < V2Controller
    before_action :authenticate_staff!
    before_action :is_staff?

    private

    def is_staff?
      render json: { error: "Unauthorized access" }, status: :unauthorized unless current_staff.present?
    end
  end
end
