class InvoiceMailer < ApplicationMailer
  layout 'agency_styled_mail'
  
  before_action { @invoice = params[:invoice] }
  before_action do
    unless @invoice.payer_type == 'User' && @invoice.invoiceable_type == 'PolicyQuote'
      raise StandardError.new("InvoiceMailer currently supports only invoices with payer_type == 'User' and invoiceable_type == 'PolicyQuote' (received Invoice ##{@invoice.id} with payer_type = '#{@invoice.payer_type}' and invoiceable_type = '#{@invoice.invoiceable_type}')")
    end
    @policy_quote = @invoice.invoiceable
    @policy = @policy_quote.policy
    @policy_application = @policy_quote.policy_application
    @agency = (@policy || @policy_application).agency || (@policy || @policy_application).account&.agency
    @user = @invoice.payer
    @from = "support@getcoveredinsurance.com"
    @to = @user.email
    @product_type = (@policy || @policy_application).policy_type.title
    @product_type = "#{@product_type} Insurance Policy" if @product_type == "Residential" || @product_type == "Commercial"
    @product_identifier = @policy.nil? ? "Quote ##{@policy_quote.reference}" : "##{@policy.number}"
  end


  def invoice_complete(invoice)
    mail(
      from: @from,
      to: @to,
      subject: [@product_type, "Invoice Paid"].join(" ")
    )
  end
  
  def invoice_missed(invoice)
    mail(
      from: @from,
      to: @to,
      subject: [@product_type, "Invoice Missed"].join(" ")
    )
  end

end
