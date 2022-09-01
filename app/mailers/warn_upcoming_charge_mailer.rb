class WarnUpcomingChargeMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_warn_upcoming_invoice(invoice)
    @user = invoice.payer
    return unless @user.is_a? User
    return unless permitted?(@user, 'upcoming_invoice')

    set_locale(@user.profile&.language)
    @invoice = invoice
    @agency = @invoice.invoiceable.agency
    @policy = @invoice.invoiceable.is_a?(Policy) ? @invoice.invoiceable : @invoice.invoiceable.policy
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @policy_type_title = t("policy_type_model.#{@policy.policy_type.title.parameterize.underscore}")
    @from = 'support@' + @branding_profile.url
    subject = t('warn_upcoming_charge_mailer.send_warn_upcoming_invoice.subject',
                agency_title: @agency.title,
                policy_number: @policy.number)
    mail(from: @from, to: @user.email, subject: subject)
  end

end
