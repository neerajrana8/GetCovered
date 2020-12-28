class BillPastDueInvoicesJob < ApplicationJob
  PAYMENT_ATTEMPTS = 3

  queue_as :default
  before_perform :set_invoices

  def perform(*_args)
    @invoices.each do |invoice|
      invoice.pay(allow_missed: true, stripe_source: :default) if invoice.charges.failed.where('created_at >= ?', invoice.due_date.midnight + 1.day).count < PAYMENT_ATTEMPTS
      reload
      next unless rent_guarantee_notify?(invoice)

      rent_guarantee_notify(invoice)
    end
  end

  private

  def set_invoices
    # WARNING: we take Policies/PolicyGroups which are BEHIND and have been so for 1-29 days... we check each invoice's charges manually to count the number of tries in perform
    curdate = Time.current.to_date
    @invoices = Invoice.where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).where(status: 'accepted', policy_id: Policy.select(:id).policy_in_system(true).current.where(auto_pay: true, billing_status: 'BEHIND', billing_behind_since: (curdate - 30.days)...curdate)))
      .or(
            Invoice.where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: PolicyGroupQuote.select(:id).where(status: 'accepted', policy_group_id: PolicyGroup.select(:id).policy_in_system(true).current.where(auto_pay: true, billing_status: 'BEHIND', billing_behind_since: (curdate - 30.days)...curdate)))
          )
      .where("due_date < '#{curdate.to_s(:db)}'")
      .where(status: 'missed', external: false)
  end

  def rent_guarantee_notify?(invoice)
    invoice.status != 'complete' &&
      invoice.charges.failed.where('created_at >= ?', invoice.due_date.midnight + 1.day).count == PAYMENT_ATTEMPTS &&
      invoice.invoiceable_type == 'PolicyQuote' &&
      invoice.invoiceable.policy_application&.policy_type_id == PolicyType::RENT_GUARANTEE_ID
  end

  def rent_guarantee_notify(invoice)
    unpaid_invoices_count = invoice.invoiceable.invoices.unpaid_past_due.count

    case unpaid_invoices_count
    when 1
      RentGuaranteeNotificationsMailer.first_nonpayment_warning(invoice: invoice).deliver_late
    when 2
      RentGuaranteeNotificationsMailer.second_nonpayment_warning(invoice: invoice).deliver_late
    end
  end
end
