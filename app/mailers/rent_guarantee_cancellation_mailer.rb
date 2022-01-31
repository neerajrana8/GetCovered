class RentGuaranteeCancellationMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_cancellation_email(policy)
    @policy = policy
    @user = @policy.primary_user
    return unless @user

    set_locale(@user.profile&.language)
    @agency = @policy.agency
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @agency_email = 'support@' + @branding_profile.url
    subject = t('rent_guarantee_cancellation_mailer.send_cancellation_email.subject',
                agency_title: @agency.title,
                policy_number: policy.number)
    mail(from: @agency_email, to: @user.email, subject: subject)
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
