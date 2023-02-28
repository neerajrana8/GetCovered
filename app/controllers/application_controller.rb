class ApplicationController < ActionController::API
  include ActionController::Helpers
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ::StandardErrorMethods

  around_action :switch_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  def redirect_home
    #TODO: why redirect to dev for all envs?
    redirect_to 'https://api-dev-v2.getcoveredinsurance.com/v2/'
  end

  def switch_locale(&action)
    locale = extract_locale_from_accept_language_header
    locale = locale && I18n.available_locales.index(locale.to_sym).present? ? locale : "en"
    I18n.with_locale(locale, &action)
  end

  protected

  def configure_permitted_parameters
    #devise_parameter_sanitizer.permit(:sign_up, keys)
    added_attrs = [:username, :email, :password, :password_confirmation, :remember_me]
    devise_parameter_sanitizer.permit :sign_up, keys: added_attrs
    devise_parameter_sanitizer.permit :account_update, keys: added_attrs
    devise_parameter_sanitizer.permit :accept_invitation, keys: [:email]
  end

  private

  def extract_locale_from_accept_language_header
    request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first || "en"
  end

end
