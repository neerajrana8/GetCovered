class RenewalMailer < ApplicationMailer
  layout 'branded_mailer'

  def policy_renewing_soon
    @policy = params[:policy]
    @agency = @policy.agency
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @organization = Agency.find(1)
    @renew_on_date = @policy.expiration_date + 1.day
    @GC_ADDRESS = Agency.get_covered.primary_address.nil? ? Address.find(1) : Agency.get_covered.primary_address
    @renewal_url = ::Mailers::TokenizedUrlProvider.new(policy_id: @policy.id, branding_profile_id: @branding_profile.id).call

    mail(to: @policy.primary_user.contact_email,
         bcc: t('system_email'),
         subject: t('renewal_mailer.policy_renewing_soon.subject'))
  end

  def policy_renewal_success
    @policy = params[:policy]
    @agency = @policy.agency
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @organization = Agency.find(1)
    @renew_on_date = @policy.expiration_date + 1.day
    @GC_ADDRESS = Agency.get_covered.primary_address.nil? ? Address.find(1) : Agency.get_covered.primary_address

    mail(to: @policy.primary_user.contact_email,
         bcc: t('system_email'),
         subject: t('renewal_mailer.policy_renewal_success.subject'))
  end

  def policy_renewal_failed
    @policy = params[:policy]
    @agency = @policy.agency
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @organization = Agency.find(1)
    @renew_on_date = @policy.expiration_date + 1.day
    @GC_ADDRESS = Agency.get_covered.primary_address.nil? ? Address.find(1) : Agency.get_covered.primary_address

    mail(to: @policy.primary_user.contact_email,
         bcc: t('system_email'),
         subject: t('renewal_mailer.policy_renewal_failed.subject'))
  end


end
