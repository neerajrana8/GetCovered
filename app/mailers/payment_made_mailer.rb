class PaymentMadeMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_successful_payment_notification(charge)
    @charge = charge
    @invoice = @charge.invoice
    @user = @invoice.payer
    if @user.is_a? User
      @branding_profile = @invoice.invoiceable.agency.branding_profiles.first
      @branding_profile = BrandingProfile.first if @branding_profile['styles']['use_gc_email_templates']
      @agency = @invoice.invoiceable.agency
      @policy = @invoice.invoiceable.is_a?(Policy) ? @invoice.invoiceable : @invoice.invoiceable.policy_group_quote.policy_group
      @from= 'support@' + @branding_profile.url
      mail(from: @from, to: @user.email, subject: "#{@agency.title} - #{@policy.number} Premium Payment Made")
    end
  end
end
