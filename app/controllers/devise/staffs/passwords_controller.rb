class Devise::Staffs::PasswordsController < DeviseTokenAuth::PasswordsController
  skip_after_action :update_auth_header, only: [:create, :edit, :update]

  def update
    # make sure user is authorized
    if require_client_password_reset_token? && resource_params[:reset_password_token]
      @resource = resource_class.with_reset_password_token(resource_params[:reset_password_token])
      return render_update_error_unauthorized unless @resource

      @token = @resource.create_token
    else
      @resource = set_user_by_token
    end

    return render_update_error_unauthorized unless @resource

    # make sure account doesn't use oauth2 provider
    unless @resource.provider == 'email'
      return render_update_error_password_not_required
    end

    # ensure that password params were sent
    unless password_resource_params[:password] && password_resource_params[:password_confirmation]
      return render_update_error_missing_password
    end

    if @resource.encrypted_password.present? && !@resource.valid_password?(params[:current_password])
      return render_update_error_current_password
    end

    params.delete(:current_password)

    if @resource.send(resource_update_method, password_resource_params)
      @resource.allow_password_change = false if recoverable_enabled?
      @resource.save!

      yield @resource if block_given?
      return render_update_success
    else
      return render_update_error
    end
  end

  private

  def render_update_error_current_password
    render_error(422, I18n.t('devise_token_auth.passwords.missing_current_password'))
  end
end
