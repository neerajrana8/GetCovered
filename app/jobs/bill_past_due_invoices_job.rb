class BillPastDueInvoicesJob < ApplicationJob
  PAYMENT_ATTEMPTS = 3

  queue_as :default
  before_perform :set_invoices

  # MOOSE WARNING: this boi is old and his time has passed.
  #                the 3-repeat functionality has been integrated into bill_due_invoices_job.
  #                this has been preserved here for now since I was just about to add renewed policy
  #                support to it and turn it back on, when I realized I could do it all in the other job.
  #                BUT IF I'M WRONG I DON'T WANNA DIG THROUGH OLD COMMITS DESPERATELY.
  #                SO, BOYO, IF YOU'RE SIGNIFICANTLY IN THE FUTURE AFTER MAY 24, 2023...
  #                THEN YOU CAN DELETE THIS!

  def perform(*_args)
    return # MOOSE WARNING: we turn this off at request of miguel and jared
    @invoices.each do |invoice|
      if invoice.stripe_charges.failed.where('created_at >= ?', invoice.due_date.midnight + 1.day).count < PAYMENT_ATTEMPTS
        invoice.pay(allow_missed: true, stripe_source: :default)
        invoice.reload
        rent_guarantee_notify(invoice) if rent_guarantee_notify?(invoice)
      end
    end
  end

  private

  def set_invoices
    return # MOOSE WARNING: we turn this off at request of miguel and jared
    # WARNING: we take Policies/PolicyGroups which are BEHIND and have been so for 1-29 days... we check each invoice's charges manually to count the number of tries in perform
    curdate = Time.current.to_date
    @invoices = Invoice.where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).where(status: 'accepted', policy_id: Policy.select(:id).policy_in_system(true).current.where(auto_pay: true, billing_status: 'BEHIND', billing_behind_since: (curdate - 30.days)...curdate))).
      or(
            Invoice.where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: PolicyGroupQuote.select(:id).where(status: 'accepted', policy_group_id: PolicyGroup.select(:id).policy_in_system(true).current.where(auto_pay: true, billing_status: 'BEHIND', billing_behind_since: (curdate - 30.days)...curdate)))
          ).
      where("due_date < '#{curdate.to_s(:db)}'").
      where(status: 'missed', external: false)
  end

  def rent_guarantee_notify?(invoice)
    invoice.status != 'complete' &&
      invoice.stripe_charges.failed.where('created_at >= ?', invoice.due_date.midnight + 1.day).count == PAYMENT_ATTEMPTS &&
      invoice.invoiceable_type == 'PolicyQuote' &&
      invoice.invoiceable.policy_application&.policy_type_id == PolicyType::RENT_GUARANTEE_ID
  end

  def rent_guarantee_notify(invoice)
    unpaid_invoices_count = invoice.invoiceable.invoices.unpaid_past_due.count

    case unpaid_invoices_count
    when 1
      RentGuaranteeNotificationsMailer.first_nonpayment_warning(invoice: invoice).deliver_later
    when 2
      RentGuaranteeNotificationsMailer.second_nonpayment_warning(invoice: invoice).deliver_later
    end
  end
end
