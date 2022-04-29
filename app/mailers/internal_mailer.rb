class InternalMailer < ApplicationMailer
  layout 'branded_mailer'
  before_action :set_variables

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.internal_mailer.error.subject
  #
  def model_error(error:)
    @subject = error.subject
    @content = error.description

    unless error.information.nil?
      @content += "<br><strong>Error Data:</strong><br>"
      @content += "#{ error.information.to_json }"
    end

    unless error.information.nil?
      @content += "<br><strong>Backtrace:</strong><br>Coming Soon."
      # @content += "#{ error.backtrace.join("<br>") }"
    end

    mail(from: "no-reply-#{ Rails.env.gsub('_', '-') }@getcovered.io",
         to: "proderror@getcovered.io",
         subject: @subject)
  end

  private

  def set_variables
    @organization = params[:organization]
    @address = @organization.primary_address()
    @branding_profile = @organization.branding_profiles.where(default: true).take
    @GC_ADDRESS = Agency.find(1).primary_address()
    @internal_mailer = true
  end
end
