class MakeInvoicesMissedJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*args)
    @invoices.each{|invoice| invoice.payment_missed(unless_processing: true) }
  end

  private

    def set_invoices
      @invoices = ::Invoice.where(status: 'available').where("due_date < '#{Time.current.to_date.to_s(:db)}'")
    end
end
