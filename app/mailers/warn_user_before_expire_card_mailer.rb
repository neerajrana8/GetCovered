class WarnUserBeforeExpireCardMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_warn_expire_card(payment_profile)
    @user = payment_profile.payer
    return unless @user.is_a? User
    return unless permitted?(@user, 'update_credit_card')

    set_locale(@user.profile&.language)
    @agency = Agency.first
    @branding_profile = @agency.branding_profiles.first
    @contact_email = @branding_profile.contact_email
    subject = t('warn_user_before_expire_card_mailer.send_warn_expire_card.subject', agency_title: @agency.title)

    mail(from: 'support@' + @branding_profile.url, to: @user.email, subject: subject)
  end
end
