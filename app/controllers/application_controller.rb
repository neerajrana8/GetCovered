class ApplicationController < ActionController::API
  include ActionController::Helpers
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ::StandardErrorMethods

  around_action :switch_locale

  def redirect_home
    redirect_to 'https://api-dev-v2.getcoveredinsurance.com/v2/'
  end

  private

  def switch_locale(&action)
    locale = extract_locale_from_accept_language_header
    I18n.with_locale(locale, &action)
  end

  def extract_locale_from_accept_language_header
    request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first || "en"
  end

end
