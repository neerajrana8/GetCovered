class Devise::Users::PasswordsController < DeviseTokenAuth::PasswordsController
  skip_after_action :update_auth_header, only: [:create, :edit, :update]

  def create
    return render_create_error_missing_email unless resource_params[:email]

    @email = get_case_insensitive_field_from_resource_params(:email)
    @resource = find_resource(:email, @email)
    if @resource
      yield @resource if block_given?
      @resource.settings['last_reset_password_base_url'] = request.headers['origin']
      # binding.pry
      @resource.save
      @resource.send_reset_password_instructions(
        email: @email,
        provider: 'email',
        redirect_url: @redirect_url,
        client_config: params[:config_name],
        request_base_url: @request_base_url
      )

      if @resource.errors.empty?
        return render_create_success
      else
        render_create_error @resource.errors
      end
    else
      render_not_found_error
    end
  end
end
