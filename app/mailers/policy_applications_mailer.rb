class PolicyApplicationsMailer < ApplicationMailer
  before_action { @policy_application = params[:policy_application] }

  def invite_to_pay
    @user = @policy_application.primary_user
    raise ArgumentError, "Policy Application: #{@policy_application.id} doesn't have a primary user" if @user.blank?
    
    # Initializes the invitation process and creates a token
    @user.tap { |user| user.skip_invitation = true }.invite!(nil, skip_invitation: true)
    token = @user.instance_variable_get(:@raw_invitation_token)
    client_url =
      BrandingProfiles::FindByObject.run!(object: @policy_application)&.url ||
      Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][:client]
    @invite_url = "https://#{client_url}/process_payment?&policy_application_id=#{@policy_application.id}&invitation_token=#{token}"

    mail(from: 'support@getcoveredinsurance.com', to: @user.email, subject: 'Policy Invoice')
  end
end
