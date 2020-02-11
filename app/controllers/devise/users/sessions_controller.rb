class Devise::Users::SessionsController < DeviseTokenAuth::SessionsController
  include SessionsMethods
  
  protected

    def render_create_success
      # @resource will have been set by set_user_by_token concern
      if @resource
        @user = @resource
        
        render template: "v2/auth/user.json", status: :ok
      else
        render json: {
          success: false,
          errors: ["Invalid login credentials"]
        }, status: 401
      end        
    end 
    
end
