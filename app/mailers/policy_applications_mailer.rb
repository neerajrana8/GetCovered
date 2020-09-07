class PolicyApplicationsMailer < ApplicationMailer
  before_action { @policy_application = params[:policy_application] }

  def invite_to_pay
    @user = @policy_application.primary_user
    raise ArgumentError, "Policy Application: #{@policy_application.id} doesn't have a primary user" if @user.blank?
    
    # Initializes the invitation process and creates a token
    @user.tap { |user| user.skip_invitation = true }.invite!(nil, skip_invitation: true)
    token = @user.instance_variable_get(:@raw_invitation_token)
    auth_params = @user.create_new_auth_token

    client_host =
      BrandingProfiles::FindByObject.run!(object: @policy_application)&.url ||
      Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][:client]

    @invite_url = Addressable::URI.new(
      scheme: 'https',
      host: client_host.split('/').last, # if someone decided to store url with a scheme
      path: 'process_payment',
      query_values: auth_params.merge!(policy_application_id: @policy_application.id, invitation_token: token)
    ).to_s

    mail(from: 'support@getcoveredinsurance.com', to: @user.email, subject: 'Policy Invoice')
  end
end
