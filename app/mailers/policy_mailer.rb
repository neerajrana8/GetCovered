class PolicyMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.policy_mailer.coverage_proof_uploaded.subject
  def coverage_proof_uploaded
    @policy = params[:policy]

    mail to: @policy.primary_user.email, subject: 'Policy Submission Received'
  end
end
