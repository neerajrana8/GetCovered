# frozen_string_literal: true

module TokenValidationMethods
  extend ActiveSupport::Concern

  included do
    def validate_token
      # @resource will have been set by set_user_by_token concern
      if @resource
        # render template: show_json_path(@resource.class.name)
        render json: @resource.as_json
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
      'v1/user/users/show.json'
    when 'Staff'
      'v1/account/staffs/show.json'
    else
      ''
    end
  end
end
