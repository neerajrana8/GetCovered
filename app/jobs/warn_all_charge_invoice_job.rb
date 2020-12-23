class WarnAllChargeInvoiceJob < ApplicationJob
  queue_as :default

  def perform
    upcoming_invoices = Invoice.where(status: 'upcoming')
                               .where("due_date = '#{(Time.current + 5.days).to_date.to_s(:db)}'")
    upcoming_invoices.find_each do |invoice|
      WarnEmailChargeInvoiceJob.perform_later(invoice)
    end
  end
end
