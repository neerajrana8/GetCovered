module V2
  class StaffController < V2Controller
    before_action :authenticate_staff!
    before_action :is_staff?

    private

    def is_staff?
      render json: { error: I18n.t('user_users_controler.unauthorized_access') }, status: :unauthorized unless current_staff.present?
    end
  end
end
