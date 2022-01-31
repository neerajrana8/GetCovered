class UserClaimMailer < ApplicationMailer
  before_action { @user = params[:user] }
  before_action { @claim = params[:claim] }
  before_action :check_user_presence
  after_action :record_mail

  default from: -> { @user.email }

  def attach_document
    # @claim = claim
    unless @claim.documents.nil?
      @claim.documents.each do |doc|
        urls = "#{Rails.application.routes.url_helpers.rails_blob_url(doc, disposition: 'attachment', host: Rails.application.credentials[:uri][ENV['RAILS_ENV'].to_sym][:api])}"
        attachments[doc.filename.to_s] = open(urls).read
      end
    end
  end

  def claim_creation_email
    @claim = @user.claims.find(@claim.id)

    mail(
      to: ['claims@getcoveredllc.com'],
      subject: "Claim was created policy number: #{@claim&.policy&.number}"
    )
  end

  private

  def check_user_presence
    return false if @user.nil?
  end

  def record_mail
    contact_record = ContactRecord.new(
      approach: 'email',
      direction: 'outgoing',
      status: 'sent',
      contactable: @user
    )

    contact_record.save
  end
end
