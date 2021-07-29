class MakeInvoicesAvailableJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*args)
    @invoices.each{|invoice| invoice.update(status: invoice.get_proper_status) }
  end

  private

    def set_invoices
      @invoices = ::Invoice.where(status: 'upcoming', external: false).where("available_date <= ?", Time.current.to_date)
    end
end
