class InvoiceMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def invoice_complete(invoice)
    set_vars(invoice)
    mail(
      from: @from,
      to: @to,
      bcc: "systememails@getcovered.io",
      subject: I18n.t('invoice_mailer.invoice_complete.subject', product_type: @product_type)
    )
  end

  def invoice_missed(invoice)
    set_vars(invoice)
    mail(
      from: @from,
      to: @to,
      bcc: "systememails@getcovered.io",
      subject: I18n.t('invoice_mailer.invoice_missed.subject', product_type: @product_type)
    )
  end

  private


    def set_vars(invoice)
      @invoice = invoice
      unless @invoice.payer_type == 'User' && @invoice.invoiceable_type == 'PolicyQuote'
        raise StandardError.new("InvoiceMailer currently supports only invoices with payer_type == 'User' and invoiceable_type == 'PolicyQuote' (received Invoice ##{@invoice.id} with payer_type = '#{@invoice.payer_type}' and invoiceable_type = '#{@invoice.invoiceable_type}')")
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
