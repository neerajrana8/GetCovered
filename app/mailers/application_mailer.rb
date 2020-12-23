class ApplicationMailer < ActionMailer::Base
  helper MailerHelper

  default from: 'info@getcoveredllc.com'
  layout 'mailer'

  private

  def set_locale(language)
    I18n.locale = language if language.present?
  end
end
