class CardInfoUpdateMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def please_update_card_info(email:, name:, policy:)
    @name = name
    @policy = policy
    @agency = policy.agency
    @branding_profile = @agency.branding_profiles&.sample
    @branding_profile = BrandingProfile.first if @branding_profile['styles']['use_gc_email_templates']
    @from = 'support@' + (@branding_profile&.url || 'getcoveredinsurance.com')
    mail(from: @from, to: email, subject: "#{@branding_profile.title} - #{@policy.number} Update Payment Information")
  end
end
