class ActivateAccountMailer < ApplicationMailer

  def third_party_insurance(policy:, user:)
    set_locale(user.profile&.language)

    @user = user

    @from = t('support_email')#"support@getcoveredinsurance.com"
    subject = t('activate_account_mailer.third_party_insurance.subject')#,

    mail(from: @from, to: user.email, subject: subject)
  end

  def master_policy_enrollment(policy:, user:)
    set_locale(user.profile&.language)

    @user = user

    @from = t('support_email')#"support@getcoveredinsurance.com"
    subject = t('activate_account_mailer.master_policy_enrollment.subject')#,

    mail(from: @from, to: user.email, subject: subject)
  end

  def renters_insurance_policy_purchase(policy:, user:)
    set_locale(user.profile&.language)

    @user = user

    @from = t('support_email')#"support@getcoveredinsurance.com"
    subject = t('activate_account_mailer.renters_insurance_policy_purchase.subject')#,

    mail(from: @from, to: user.email, subject: subject)
  end
end
