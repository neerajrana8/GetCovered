class WarnEmailChargeInvoiceJob < ApplicationJob
  queue_as :default

  def perform(invoice)
    WarnUpcomingChargeMailer.send_warn_upcoming_invoice(invoice).deliver
  end
end
