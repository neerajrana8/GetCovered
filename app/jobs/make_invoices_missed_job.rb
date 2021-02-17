class MakeInvoicesMissedJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*args)
    @invoices.each{|invoice| invoice.update(status: 'missed') }
  end

  private

    def set_invoices
      @invoices = ::Invoice.where(status: 'available', external: false).where("due_date < ?", Time.current.to_date)
    end
end
