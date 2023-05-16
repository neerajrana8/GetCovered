module Policies
  class CancellationMailer < ApplicationMailer
    before_action :set_variables

    default to: -> { @user.email },
            from: -> { 'no-reply@getcoveredinsurance.com' },
            bcc: -> { 'systememails@getcovered.io' },
            cc: 'support@getcoveredinsurance.com'

    def refund_request
      mail(
        subject: I18n.t('cancellation_mailer.refund_request.subject', agency_policy_type: @agency_policy_type),
        bcc: return_bcc_field,
        cc:  t('support_email')
      )
    end

    def cancel_request
      mail(
        subject: I18n.t('cancellation_mailer.cancel_request.subject', agency_policy_type: @agency_policy_type),
        bcc: return_bcc_field,
        cc:  t('support_email')
      )
    end

    def cancel_confirmation
      mail(
        subject: I18n.t('cancellation_mailer.cancel_confirmation.subject', agency_policy_type: @agency_policy_type),
        bcc: return_bcc_field,
        cc:  t('support_email')
      )
    end

    private

    def set_variables
      @policy = params[:policy]
      @request_date = params[:change_request]&.created_at
      @without_request = params[:without_request]
      @user = @policy.primary_user
      @agency = @policy.agency
      @branding_profile = @policy.branding_profile || BrandingProfile.global_default
      @contact_email = @branding_profile.contact_email
      @contact_phone = @branding_profile.contact_phone

      I18n.locale = @user&.profile&.language if @user&.profile&.language&.present?

      @policy_type_title = I18n.t("policy_type_model.#{@policy.policy_type.title.parameterize.underscore}")
      @agency_policy_type = "#{@agency.title} - #{@policy_type_title}"
    end

    def return_bcc_field
      "#{@agency.contact_info.dig('contact_email')};#{t('system_email')}"
    end


  end
end
