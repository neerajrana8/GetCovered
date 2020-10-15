module Policies
  class CancellationMailer < ApplicationMailer
    before_action :set_variables

    default to: -> { @user.email },
            from: -> { 'no-reply@getcoveredinsurance.com' }

    def refund_request
      mail(subject: "#{@agency.title} - #{@policy.policy_type.title} Refund Request", bcc: @agency.contact_info['contact_email'])
    end

    def cancel_request
      mail(subject: "#{@agency.title} - #{@policy.policy_type.title} Cancellation Request", bcc: @agency.contact_info['contact_email'])
    end

    def cancel_confirmation
      mail(subject: "#{@agency.title} - #{@policy.policy_type.title} Policy Cancellation", bcc: @agency.contact_info['contact_email'])
    end

    private

    def set_variables
      @policy = params[:policy]
      @request_date = params[:change_request]&.created_at
      @without_request = params[:without_request]
      @user = @policy.primary_user
      @agency = @policy.agency
      @contact_email =
        BrandingProfiles::FindByObject.run!(object: @agency)&.
          branding_profile_attributes&.
          find_by_name('contact_email')&.
          value
    end
  end
end
