class WarnUpcomingChargeMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_warn_upcoming_invoice(invoice)
    @user = invoice.payer
    if @user.is_a? User
      @branding_profile = invoice.invoiceable.agency.branding_profiles.first
      @branding_profile = BrandingProfile.first if @branding_profile['styles']['use_gc_email_templates']
      @invoice = invoice
      @agency = @invoice.invoiceable.agency
      @policy = @invoice.invoiceable.is_a?(Policy) ? @invoice.invoiceable : @invoice.invoiceable.policy
      @from = 'support@' + @branding_profile.url
      mail(from: @from, to: @user.email, subject: "#{@agency.title} - #{@policy.number} Upcoming Premium Payment")
    end
  end
end
