class PolicyApplicationsMailer < ApplicationMailer
  before_action { @policy_application = params[:policy_application] }
  after_action :record_mail

  def invite_to_pay
    @user = @policy_application.primary_user
    raise ArgumentError, "Policy Application: #{@policy_application.id} doesn't have a primary user" if @user.blank?
    
    # Initializes the invitation process and creates a token
    @user.tap { |user| user.skip_invitation = true }.invite!(nil, skip_invitation: true)
    token = @user.instance_variable_get(:@raw_invitation_token)
    auth_token = EncryptionService.encrypt("User/#{@user.email}/#{@user.encrypted_password}")

    client_host =
      BrandingProfiles::FindByObject.run!(object: @policy_application)&.url ||
      Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][:client]

    @invite_url = Addressable::URI.new(
      scheme: 'https',
      host: client_host.split('/').last, # if someone decided to store url with a scheme
      path: 'process_payment',
      query_values: { policy_application_id: @policy_application.id, invitation_token: token, auth_token: auth_token }
    ).to_s

    mail(
      from: 'no-reply@getcoveredinsurance.com',
      to: @user.email,
      subject: subject
    )
  end

  private

  def subject
    application_holder = @policy_application.account || @policy_application.agency
    "Finish Registering Your #{application_holder&.title} Account - #{@policy_application.policy_type.title} policy"
  end

  def record_mail
    user = @policy_application.primary_user

    contact_record = ContactRecord.new(
      direction: 'outgoing',
      approach: 'email',
      status: 'sent',
      contactable: user
    )

    contact_record.save
  end
end
