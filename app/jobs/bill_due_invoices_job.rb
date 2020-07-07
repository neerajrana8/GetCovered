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
    policy_ids = Policy.policy_in_system(true).current.where(auto_pay: true).pluck(:id)
    policy_group_ids = PolicyGroup.policy_in_system(true).current.where(auto_pay: true).pluck(:id)
    
    policy_quote_ids = PolicyQuote.where(status: 'accepted', policy_id: policy_ids).pluck(:id)
    policy_group_quote_ids = PolicyGroupQuote.where(status: 'accepted', policy_group_id: policy_group_ids).pluck(:id)
    
    @invoices = Invoice.where(invoiceable_type: 'PolicyQuote', invoiceable_id: policy_quote_ids)
                      .or(
                        Invoice.where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: policy_group_quote_ids)
                      )
                      .where("due_date <= '#{Time.current.to_date.to_s(:db)}'")
                      .where(status: 'available')
  end
end
