class BillUnpaidInvoicesJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*_args)
    @invoices.each do |invoice|
      invoice.pay(allow_missed: true, stripe_source: :default)
    end
  end

  private

  def set_invoices
    curdate = Time.current.to_date
    @invoices = Invoice.where(invoiceable_type: 'PolicyQuote', payer: arguments.first,
                              invoiceable_id: PolicyQuote.select(:id).where(status: 'accepted', policy_id: Policy.select(:id).policy_in_system(true).current.where(auto_pay: true, billing_status: 'BEHIND', billing_behind_since: (curdate - 30.days)...(curdate))))
                       .where("due_date < '#{curdate.to_s(:db)}'")
                       .where(status: 'missed', external: false)
  end
end
