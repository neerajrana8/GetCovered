class WarnUpcomingChargeMailerPreview < ActionMailer::Preview
  def send_warn_upcoming_invoice
    WarnUpcomingChargeMailer.send_warn_upcoming_invoice(Invoice.last)
  end
end

