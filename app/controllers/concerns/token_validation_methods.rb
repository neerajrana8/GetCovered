# frozen_string_literal: true

module TokenValidationMethods
  extend ActiveSupport::Concern

  included do
    def validate_token
      # @resource will have been set by set_user_by_token concern
      if @resource
        render template: show_json_path(@resource.class.name)
      else
        render json: {
          success: false,
          errors: ["Invalid login credentials"]
        }, status: 401
      end  
    end
  end

  def show_json_path(resource_type)
    case resource_type
    when 'User'
      'v2/user/users/show'
    when 'Staff'
      'v2/staff_super_admin/staffs/show'
    else
      ''
    end
  end
end
