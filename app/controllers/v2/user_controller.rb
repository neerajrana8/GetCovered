##
# V2 User Controller
# File: app/controllers/v2/user_controller.rb

module V2
  class UserController < V2Controller
    before_action :authenticate_user!

    private

    def view_path
      super + '/user'
    end

    # this method returns:
    # - current user if you trying to get user/users with the same id;
    # - all model_class' objects (example result: current_user.invoices) if model_id is nil;
    # - find a model_class' object (example result: current_user.invoices.find(model_id)) if model_id present.
    def access_model(model_class, model_id = nil)
      if model_class == ::User && (model_id == current_user.id.to_s) # model_id can be nil or string
        current_user
      else
        model_class_params = model_id.nil? ? [:itself] : [:find, model_id]
        current_user.send(model_class.name.underscore.pluralize).send(*model_class_params)
      end
    end
  end
end
