class InternalMailer < ApplicationMailer
  layout 'branded_mailer'
  before_action :set_variables

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.internal_mailer.error.subject
  #
  def model_error(error:)
    @content = error.description
    mail(from: "no-reply-#{ Rails.env.gsub('_', '-') }@getcovered.io",
         to: "proderror@getcovered.io",
         subject: error.subject)
  end

  private

  def set_variables
    @organization = params[:organization]
    @address = @organization.primary_address()
    @branding_profile = @organization.branding_profiles.where(default: true).take
    @GC_ADDRESS = Agency.find(1).primary_address()
  end
end
