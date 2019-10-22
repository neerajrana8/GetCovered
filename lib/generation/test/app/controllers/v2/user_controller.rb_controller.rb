##
# V2 User Controller
# File: app/controllers/v2/user_controller.rb_controller.rb

module V2
  class UserController < V1Controller
    
    before_action :authenticate_user!
    
    private

      def view_path
        super + "/user"
      end
      
      def access_model(model_class, model_id = nil)
        model_class == ::User && model_id == current_user.id ? current_user : current_user.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id]))
      end
      
  end
end
