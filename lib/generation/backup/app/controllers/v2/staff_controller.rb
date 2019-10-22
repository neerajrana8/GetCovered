# frozen_string_literal: true

# V2 Staff Controller
# file: app/controllers/v1/staff_controller.rb
module V2
  class StaffController < V1Controller
    before_action :authenticate_staff!
    before_action :set_scope_association
    before_action :set_account, if: -> { current_staff.staff? }

    private

    def set_scope_association
      if current_staff.staff?
        @scope_association = current_staff.account
      elsif current_staff.agent?
        @scope_association = current_staff.agency
      end
    end

    def set_account
      @account = current_staff.account
    end

    def only_staff
      unless current_staff.staff? || current_staff.super_admin?
        render json: {
                 success: false,
                 errors: ['Unauthorized Access']
               }, status: 401
        return
      end
    end

    def only_agents
      unless current_staff.agent? || current_staff.super_admin?
        render json: {
                 success: false,
                 errors: ['Unauthorized Access']
               }, status: 401
        return
      end
    end

    def only_super_admins
      unless current_staff.super_admin?
        render json: {
                 success: false,
                 errors: ['Unauthorized Access']
               }, status: 401
        return
      end
    end

    def view_path
      super + '/staff'
    end
  end
end
