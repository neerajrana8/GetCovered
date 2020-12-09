class CustomDeviseMailer < Devise::Mailer
  helper MailerHelper
  before_action do
    I18n.locale = @resource.profile&.language || I18n.default_locale
    ap @resource
  end

  def invitation_instructions(record, token, opts = {})
    if opts[:policy_application].present?
      @policy_application = opts[:policy_application]
      client_host = headers['client_host'] || Rails.application.credentials.uri[ENV["RAILS_ENV"].to_sym][:client]
      @accept_link = "#{client_host}/auth/accept-invitation/#{@token}"

      opts[:subject] = t('devise.mailer.product_invitation_instruction.subject',
                         agency_title: '@policy_application.agency&.title',
                         policy_type_title: @policy_application.policy_type.title)
      opts[:template_name] = 'product_invitation_instructions'
    end

    super
  end
end
