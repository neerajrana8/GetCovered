class PaymentMadeMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_successful_payment_notification(charge)
    @charge = charge
    @invoice = @charge.invoice
    @user = @invoice.payer

    return unless @user.is_a? User

    set_locale(@user.profile&.language)
    @agency = @invoice.invoiceable.agency
    @policy = @invoice.invoiceable.is_a?(Policy) ? @invoice.invoiceable : @invoice.invoiceable.policy
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @from = 'support@' + @branding_profile.url
    @policy_type_title = I18n.t("policy_type_model.#{@policy.policy_type.title.parameterize.underscore}")
    subject = I18n.t("payment_made_mailer.send_successful_payment_notification.subject",
                     agency_title: @agency.title,
                     policy_type: @policy_type_title)
    mail(from: @from, bcc: "systememails@getcovered.io", to: @user.email, subject: subject)
  end

end
