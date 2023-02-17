class Devise::Staffs::SessionsController < DeviseTokenAuth::SessionsController
  include SessionsMethods

  def create
    super
  end

  protected

  def render_create_success
    # @resource will have been set by set_user_by_token concern
    if @resource
      @staff = @resource

      render template: 'v2/shared/staffs/show.json', status: :ok
    else
      # https://stackoverflow.com/questions/32752578/whats-the-appropriate-http-status-code-to-return-if-a-user-tries-logging-in-wit
      render json: {
        success: false,
        errors: [I18n.t('user_users_controler.invalid_login_credentials')]
      }, status: 401
    end
  end

end
