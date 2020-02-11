class Devise::Users::SessionsController < DeviseTokenAuth::SessionsController
  include SessionsMethods
  
  protected

    def render_create_success
      # @resource will have been set by set_user_by_token concern
      if @resource
        @user = @resource
        
        render json: @user.to_json({ :include => :profile }),
               status: 200
      else
        render json: {
          success: false,
          errors: ["Invalid login credentials"]
        }, status: 401
      end        
    end 
    
end
