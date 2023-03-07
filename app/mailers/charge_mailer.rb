class ChargeMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def charge_failed(charge)
    set_vars(charge)
    mail(
      from: @from,
      to: @to,
      bcc: "systememails@getcovered.io",
      subject: I18n.t('charge_mailer.charge_failed.subject', product_type: @product_type)
    )
  end

  private


    def set_vars(charge)
      @charge = charge
      @invoice = @charge.invoice
      unless @invoice.payer_type == 'User' && @invoice.invoiceable_type == 'PolicyQuote'
        raise StandardError.new("ChargeMailer currently supports only StripeCharges whose invoices have payer_type == 'User' and invoiceable_type == 'PolicyQuote' (received #{@charge.class.name} ##{@charge.id} associated with Invoice ##{@invoice.id} with payer_type = '#{@invoice.payer_type}' and invoiceable_type = '#{@invoice.invoiceable_type}')")
      end
      @policy_quote = @invoice.invoiceable
      @policy = @policy_quote.policy
      @policy_application = @policy_quote.policy_application
      @agency = (@policy || @policy_application).agency || (@policy || @policy_application).account&.agency
      @branding_profile = @agency.default_branding_profile
      @user = @invoice.payer
      @from = "support@getcoveredinsurance.com"
      @to = @user.email
      @product_type = (@policy || @policy_application).policy_type.title
      @product_type = "#{@product_type} Insurance Policy" if @product_type == "Residential" || @product_type == "Commercial"
      @product_identifier = @policy.nil? ? "Quote ##{@policy_quote.reference}" : "##{@policy.number}"
    end


end
