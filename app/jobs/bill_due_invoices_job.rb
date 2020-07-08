class BillDueInvoicesJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*_args)
    @invoices.each do |invoice|
      invoice.pay(allow_upcoming: true, stripe_source: :default)
    end
  end

  private

  def set_invoices
    @invoices = Invoice.where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).where(status: 'accepted', policy_id: Policy.select(:id).policy_in_system(true).current.where(auto_pay: true)))
                       .or(
                          Invoice.where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: PolicyGroupQuote.select(:id).where(status: 'accepted', policy_group_id: PolicyGroup.select(:id).policy_in_system(true).current.where(auto_pay: true)))
                       )
                       .where("due_date <= '#{Time.current.to_date.to_s(:db)}'")
                       .where(status: 'available', external: false)
  end
end
