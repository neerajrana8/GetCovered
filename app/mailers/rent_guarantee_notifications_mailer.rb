class RentGuaranteeNotificationsMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def first_nonpayment_warning(invoice:)
    @user = invoice.payer
    return unless @user.is_a? User
    return unless permitted?(@user, 'rent_guarantee_warnings')

    set_locale(@user.profile&.language)

    @invoice = invoice
    @agency = @invoice.invoiceable.agency
    @policy = @invoice.invoiceable.is_a?(Policy) ? @invoice.invoiceable : @invoice.invoiceable.policy
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @policy_type_title = t("policy_type_model.#{@policy.policy_type.title.parameterize.underscore}")
    @from = 'support@' + @branding_profile.url
    subject = t('rent_guarantee_notifications_mailer.first_nonpayment_warning.subject',
                agency_title: @agency.title)
    mail(from: @from, to: @user.email, subject: subject)
    record_mail(@user)
  end

  def second_nonpayment_warning(invoice:)
    @user = invoice.payer
    return unless @user.is_a? User
    return unless permitted?(@user, 'rent_guarantee_warnings')

    set_locale(@user.profile&.language)

    @invoice = invoice
    @agency = @invoice.invoiceable.agency
    @policy = @invoice.invoiceable.is_a?(Policy) ? @invoice.invoiceable : @invoice.invoiceable.policy
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @policy_type_title = t("policy_type_model.#{@policy.policy_type.title.parameterize.underscore}")
    @from = 'support@' + @branding_profile.url
    days_before_cancellation = @policy.carrier.carrier_policy_types.find_by_policy_type_id(@policy.policy_type_id).days_late_before_cancellation
    @calculated_cancellation_date = @policy.billing_behind_since + days_before_cancellation.days
    subject = t('rent_guarantee_notifications_mailer.second_nonpayment_warning.subject',
                agency_title: @agency.title)
    mail(from: @from, to: @user.email, subject: subject)
    record_mail(@user)
  end

  private

  def record_mail(user)
    contact_record = ContactRecord.new(
      approach: 'email',
      direction: 'outgoing',
      status: 'sent',
      contactable: user
    )

    contact_record.save
  end
end
