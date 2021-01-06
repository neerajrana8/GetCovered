class CardInfoUpdateMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def please_update_card_info(user:, policy:)
    set_locale(user.profile&.language)

    @user = user
    @policy = policy
    @agency = policy.agency
    @branding_profile = @agency.branding_profiles&.sample
    @from = 'support@' + (@branding_profile&.url || 'getcoveredinsurance.com')
    subject = t('card_info_update_mailer.please_update_card_info.subject',
                agency_title: @agency.title,
                policy_number: @policy.number)
    mail(from: @from, to: user.email, subject: subject)
  end
end
