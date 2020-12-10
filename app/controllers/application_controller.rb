class ApplicationController < ActionController::API
  include ActionController::Helpers
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ::StandardErrorMethods

  around_action :switch_locale

  def redirect_home
    redirect_to 'https://api-dev-v2.getcoveredinsurance.com/v2/'
  end

  def switch_locale(&action)
    begin
      locale = extract_locale_from_accept_language_header
      I18n.with_locale(locale, &action)
    rescue  I18n::InvalidLocale => ex
      I18n.with_locale("en", &action)
    ensure
      I18n.with_locale("en", &action) if locale.nil?
    end
  end

  private

  def extract_locale_from_accept_language_header
    request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first
  end

end
