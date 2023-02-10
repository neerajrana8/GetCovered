# frozen_string_literal: true

module SessionsMethods
  extend ActiveSupport::Concern

  included do

    def destroy
      # remove auth instance variables so that after_action does not run
      user = remove_instance_variable(:@resource) if @resource
      client = @token.client
      @token.clear!

      if user && client && user.tokens[client]
        user.tokens.delete(client)
        user.save!

        if DeviseTokenAuth.cookie_enabled
          # If a cookie is set with a domain specified then it must be deleted with that domain specified
          # See https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html
          cookies.delete(DeviseTokenAuth.cookie_name, domain: DeviseTokenAuth.cookie_attributes[:domain])
        end

        yield user if block_given?

        render_destroy_success
      else
        render_destroy_error
      end
    end

    # redefine method from the DeviseTokenAuth::SessionsController to enable remember_me functional without cookies
    def create
      # Check
      field = (resource_params.keys.map(&:to_sym) & resource_class.authentication_keys).first

      @resource = nil
      if field
        q_value = get_case_insensitive_field_from_resource_params(field)

        @resource = find_resource(field, q_value)
      end

      if @resource && valid_params?(field, q_value) && (!@resource.respond_to?(:active_for_authentication?) || @resource.active_for_authentication?)
        valid_password = valid_password?(resource_params[:password])
        if (@resource.respond_to?(:valid_for_authentication?) && !@resource.valid_for_authentication? { valid_password }) || !valid_password
          return render_create_error_bad_credentials
        end

    #    binding.pry
        # Begin of the modified fragment
        lifespan = request.headers.env['HTTP_REMEMBER_ME'] == 'true' ? Devise.remember_for : DeviseTokenAuth.token_lifespan
        @token = @resource.create_token(lifespan: lifespan)
        #End of the modified fragment

        @resource.save

        sign_in(:user, @resource, store: false, bypass: false)

        yield @resource if block_given?

        render_create_success
      elsif @resource && !(!@resource.respond_to?(:active_for_authentication?) || @resource.active_for_authentication?)
        if @resource.respond_to?(:locked_at) && @resource.locked_at
          render_create_error_account_locked
        else
          render_create_error_not_confirmed
        end
      else
        render_create_error_bad_credentials
      end
     end

    def render_create_success
      # @resource will have been set by set_user_by_token concern
      if @resource
        render json: @resource.as_json
      else
        # https://stackoverflow.com/questions/32752578/whats-the-appropriate-http-status-code-to-return-if-a-user-tries-logging-in-wit
        render json: {
          success: false,
          errors: ['Invalid login credentials']
        }, status: 401
      end
    end
  end

  def show_json_path(resource_type)
    case resource_type
    when 'User'
      'v1/user/users/show.json'
    when 'Staff'
      'v1/account/staffs/show.json'
    else
      ''
    end
  end

  private

  def valid_password?(password)
    Devise::Encryptor.compare(resource_class, @resource.encrypted_password, password)
  end
end
