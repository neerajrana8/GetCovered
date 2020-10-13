class RentGaranteeCancellationMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_cancellation_email(policy)
    @policy = policy
    @user = @policy.primary_user
    return unless @user
    @agency = @policy.agency
    @branding_profile = @agency.branding_profiles.first
    @branding_profile = BrandingProfile.first if @branding_profile['styles']['use_gc_email_templates']
    @agency_email = 'support@' + @branding_profile.url
    mail(from: @agency_email, to: @user.email, subject: "#{@agency.title} - #{@policy.number} Policy Cancellation")
  end
end
