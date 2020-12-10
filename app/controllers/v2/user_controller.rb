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

    def user_from_invitation_token
      @user = ::User.find_by_invitation_token(params[:invitation_token], true)
      return if params[:invitation_token] && @user
      render json: { errors: [ I18n.t('user_controller.invalid_token')] }, status: :not_acceptable
    end

    # this method returns:
    # - current user if you trying to get user, even if you try to get/modify user with another id;
    # - all model_class' objects (example result: current_user.invoices) if model_id is nil;
    # - find a model_class' object (example result: current_user.invoices.find(model_id)) if model_id present.
    def access_model(model_class, model_id = nil)
      if model_class == ::User
        current_user
      else
        model_class_params = model_id.nil? ? [:itself] : [:find, model_id]
        current_user.send(model_class.name.underscore.pluralize).send(*model_class_params)
      end
    end
  end
end
