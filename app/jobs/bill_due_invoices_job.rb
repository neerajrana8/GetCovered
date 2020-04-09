class BillDueInvoicesJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*_args)
    @invoices.each { |invoice| invoice.pay(allow_upcoming: true) }
  end

  private

  def set_invoices
    @invoices = Invoice.joins("LEFT JOIN policies ON (policies.id = invoices.invoiceable_id AND invoices.invoiceable_type = 'Policy')")
                       .where(policies: { billing_enabled: true, policy_in_system: true }, due_date: Time.current.to_date)
                       .available # MOOSE WARNING: extend for PolicyGroup when it exists
  end
end
