# frozen_string_literal: true

module PasswordMethods
  extend ActiveSupport::Concern

  included do
    define_method "#{name.split('::').first.tableize.singularize}_params" do
      params.permit(:password, :password_confirmation)
    end
    private "#{name.split('::').first.tableize.singularize}_params"

    def update
      resource_type = self.class.name.split('::').first.singularize.constantize
      reset_code = params['reset_password_token']
      reset_password_token = Devise.token_generator.digest(self, :reset_password_token, reset_code)
      resource = resource_type.find_by reset_password_token: reset_password_token

      raise ActionController::RoutingError, 'Not Found' if resource.nil?

      params = send("#{resource_type.name.tableize.singularize}_params")
      if params[:password] == params[:password_confirmation] &&
         resource.update(params)

        @response = {
          status: :success,
          statusText: 'Password has been updated'
        }
        render json: @response
      else
        render json: resource.errors, status: :unprocessable_entity
      end
    end
  end
end
