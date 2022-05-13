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

    unless error.backtrace.nil?
      @content += "<br><br><strong>Backtrace:</strong><br>"
      JSON.parse(error.backtrace).each do |error_line|
        @content += '<span style="font-size: 16px">' + error_line + '</span><br>'
      end
    end

    mail(from: "no-reply-#{ Rails.env.gsub('_', '-') }@getcovered.io",
         to: "proderror@getcovered.io",
         subject: @subject,
         template_name: 'html_content')
  end

  def claim_notification(claim:)
    @subject = claim.subject.nil? ? "New Claim Submitted on #{ claim.created_at.strftime('%B %d, %Y - %H:%I:%S') }" :
                 "New Claim Submitted: #{ claim.subject } on #{ claim.created_at.strftime('%B %d, %Y - %H:%I:%S') }"
    @content = String.new

    unless claim.subject.nil?
      @content += '<strong>Subject:</strong> ' + claim.subject + '<br>'
    end

    unless claim.description.nil?
      @content += '<strong>Description:</strong> ' + claim.description + '<br>'
    end

    unless claim.claimant.nil?
      if claim.claimant_type == "User"
        @content += '<strong>Claimant Type:</strong> Policy Holder<br>'
        @content += '<strong>Claimant:</strong> ' + claim.claimant&.profile&.full_name + '<br>'
      elsif claim.claimant_type == "Account"
        @content += '<strong>Claimant Type:</strong> Property Manager<br>'
        @content += '<strong>Claimant:</strong> ' + claim.claimant&.title + '<br>'
      end
    end

    unless claim.policy.nil?
      @content += '<strong>Policy Type:</strong> ' + claim.policy.policy_type.title + '<br>'
      @content += '<strong>Policy Number:</strong> ' + claim.policy.number + '<br>'
    end

    unless claim.time_of_loss.nil?
      @content += '<strong>Date of Loss:</strong> ' + claim.time_of_loss.strftime('%B %d, %Y - %H:%I:%S') + '<br>'
    end

    @content += '<strong>Submission Date:</strong> ' + claim.created_at.strftime('%B %d, %Y - %H:%I:%S') + '<br>'

    mail(from: "no-reply-#{ Rails.env.gsub('_', '-') }@getcovered.io",
         to: "support@getcoveredinsurance.com",
         subject: @subject,
         template_name: 'html_content')
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
