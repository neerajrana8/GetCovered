class CustomDeviseMailer < Devise::Mailer
  helper MailerHelper

  def invitation_instructions(record, token, opts = {})
    if opts[:policy_application].present?
      @policy_application = opts[:policy_application]
      opts[:subject] = "Finish Registering Your #{@policy_application.agency&.title} Account - #{@policy_application.policy_type.title}"
      opts[:template_name] = 'product_invitation_instructions'
    end

    super
  end
end
