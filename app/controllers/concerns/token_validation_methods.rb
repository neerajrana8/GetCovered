# frozen_string_literal: true

module TokenValidationMethods
  extend ActiveSupport::Concern

  included do
    def validate_token
      # @resource will have been set by set_user_by_token concern
      if @resource
        render json: @resource.as_json
      else
        render json: {
          success: false,
          errors: ["Invalid login credentials"]
        }, status: 401
      end
    end
  end
end
