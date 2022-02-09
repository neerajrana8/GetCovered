# frozen_string_literal: true

module SessionsMethods
  extend ActiveSupport::Concern

  included do

    # redefine method from the DeviseTokenAuth::SessionsController to enable remember_me functional  without cookies
    def create
      # Check
      field = (resource_params.keys.map(&:to_sym) & resource_class.authentication_keys).first

      @resource = nil
      if field
        q_value = get_case_insensitive_field_from_resource_params(field)

        @resource = find_resource(field, q_value)
      end

      if @resource && valid_params?(field, q_value) && (!@resource.respond_to?(:active_for_authentication?) || @resource.active_for_authentication?)
        valid_password = @resource.valid_password?(resource_params[:password])
        if (@resource.respond_to?(:valid_for_authentication?) && !@resource.valid_for_authentication? { valid_password }) || !valid_password
          return render_create_error_bad_credentials
        end

        # Begin of the modified fragment
        lifespan = request.headers.env['HTTP_REMEMBER_ME'] == 'true' ? Devise.remember_for : DeviseTokenAuth.token_lifespan
        @token = @resource.create_token(lifespan: lifespan)
        # End of the modified fragment

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
end
