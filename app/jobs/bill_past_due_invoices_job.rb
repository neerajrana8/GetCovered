class BillPastDueInvoicesJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices


  def perform(*_args)
    @invoices.each do |invoice|
      invoice.pay(allow_missed: true, stripe_source: :default) if invoice.charges.failed.count < 3
    end
  end

  private

    def set_invoices
      # WARNING: we take Policies/PolicyGroups which are BEHIND and have been so for 1-29 days... we check each invoice's charges manually to count the number of tries in perform
      curdate = Time.current.to_date
      @invoices = Invoice.where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).where(status: 'accepted', policy_id: Policy.select(:id).policy_in_system(true).current.where(auto_pay: true, billing_status: 'BEHIND', billing_behind_since: (curdate - 30.days)...(curdate))))
                         .or(
                            Invoice.where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: PolicyGroupQuote.select(:id).where(status: 'accepted', policy_group_id: PolicyGroup.select(:id).policy_in_system(true).current.where(auto_pay: true, billing_status: 'BEHIND', billing_behind_since: (curdate - 30.days)...(curdate))))
                         )
                         .where("due_date < '#{curdate.to_s(:db)}'")
                         .where(status: 'missed')
    end


end
