class Devise::Staffs::SessionsController < DeviseTokenAuth::SessionsController
  include SessionsMethods
  
  protected

    def render_create_success
      # @resource will have been set by set_user_by_token concern
      if @resource
        @staff = @resource
        
        render template: "v2/auth/staff.json", status: :ok
      else
        render json: {
          success: false,
          errors: ["Invalid login credentials"]
        }, status: 401
      end        
    end 
    
end
