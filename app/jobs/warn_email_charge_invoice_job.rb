class WarnEmailChargeInvoiceJob < ApplicationJob
  queue_as :default

  def perform(invoice)
    policy = invoice.invoiceable_type == 'Policy' ? invoice.invoiceable : invoice.invoiceable_type == 'PolicyQuote' ? invoice.invoiceable.policy
    WarnUpcomingChargeMailer.send_warn_upcoming_invoice(invoice).deliver unless policy.nil?
  end
end
