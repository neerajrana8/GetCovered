class BillDueInvoicesJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*_args)
    @invoices.each do |invoice|
      invoice.pay(allow_upcoming: true, stripe_source: :default) if (invoice.invoiceable_type == 'PolicyQuote' && invoice.invoiceable.policy.billing_enabled && invoice.invoiceable.policy.policy_in_system) ||
                                                                    (invoice.invoiceable_type == 'PolicyGroupQuote' && invoice.invoiceable.policy_group.billing_enabled)
    end
  end

  private

  def set_invoices
    @invoices = Invoice.where("due_date <= '#{Time.current.to_date.to_s(:db)}'").where(status: 'available', external: false)
  
    #@invoices = Invoice.joins("LEFT JOIN policies ON (policies.id = invoices.invoiceable_id AND invoices.invoiceable_type = 'Policy')")
    #                   .where(policies: { billing_enabled: true, policy_in_system: true }, due_date: Time.current.to_date)
    #                   .available # MOOSE WARNING: extend for PolicyGroup when it exists
  end
end
