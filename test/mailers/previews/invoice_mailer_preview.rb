class InvoiceMailerPreview < ActionMailer::Preview
  def invoice_complete
    InvoiceMailer.invoice_complete(Invoice.last)
  end

  def invoice_missed
    InvoiceMailer.invoice_missed(Invoice.last)
  end

end
