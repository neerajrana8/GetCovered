class BillDueInvoicesJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*args)
    @invoices.each { |invoice| invoice.pay(allow_upcoming: true) }
  end

  private

    def set_invoices
      @invoices = Invoice.includes(:policy).where(policies: { billing_enabled: true, policy_in_system: true }, due_date: Time.current.to_date).available
    end
end
