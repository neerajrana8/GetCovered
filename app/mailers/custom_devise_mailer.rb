class CustomDeviseMailer < Devise::Mailer
  helper MailerHelper

  def invitation_instructions(record, token, opts = {})
    set_locale(record)
    if opts[:policy_application].present?
      @policy_application = opts[:policy_application]
      client_host = headers['client_host'] || Rails.application.credentials.uri[ENV["RAILS_ENV"].to_sym][:client]
      @accept_link = "#{client_host}/auth/accept-invitation/#{token}"
      @policy_type_title = I18n.t("policy_type_model.#{@policy_application.policy_type.title.parameterize.underscore}")

      opts[:subject] = t('devise.mailer.product_invitation_instruction.subject',
                         agency_title: @policy_application.agency&.title,
                         policy_type_title: @policy_type_title)
      opts[:template_name] = 'product_invitation_instructions'
    end

    super
  end

  def reset_password_instructions(record, token, opts={})
    set_locale(record)
    super
  end

  private

  def set_locale(record)
    I18n.locale = record&.profile&.language if record&.profile&.language&.present?
  end
end
