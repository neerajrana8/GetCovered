class ApplicationMailer < ActionMailer::Base
  helper MailerHelper

  default from: 'info@getcoveredllc.com'
  layout 'mailer'

  private

  def set_locale(language)
    I18n.locale = language if language.present?
  end

  def permitted?(notifyable, action)
    notification_setting = notifyable.notification_settings.find_by_action(action)

    notification_setting.present? ? notification_setting.enabled? : true
  end
end
