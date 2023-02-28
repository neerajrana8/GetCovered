class Devise::Users::RegistrationsController < DeviseTokenAuth::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]

  # POST /resource
  def create
    super
    return unless @resource.persisted?
  end

  protected

  def build_resource
    @resource            = resource_class.new(sign_up_params)
    @resource.provider   = provider

    # honor devise configuration for case_insensitive_keys
    @resource.email =
      if resource_class.case_insensitive_keys.include?(:email)
        sign_up_params[:email].try(:downcase)
      else
        sign_up_params[:email]
      end

    @resource.invitation_accepted_at = nil
    @resource.profile.language = I18n.locale if @resource&.profile&.present?
  end

  def render_create_error
    render json: standard_error(:user_creation_error, nil, @resource.errors.full_messages), status: 422
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation, profile_attributes: %i[
                                        first_name middle_name last_name contact_email contact_phone birth_date language
                                      ]])
  end
end
