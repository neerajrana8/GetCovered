class BillDueInvoicesJob < ApplicationJob
  queue_as :default
  before_perform :set_invoices

  def perform(*_args)
    invoiceable_id = nil
    invoiceable_type = nil
    to_charge = []
    @invoices.each do |invoice|
      # charge the elements of to_charge if needed
      if invoiceable_id != invoice.invoiceable_id || invoiceable_type != invoice.invoiceable_type
        invoiceable_id = invoice.invoiceable_id
        invoiceable_type = invoice.invoiceable_type
        charge_invoice_group(to_charge)
        to_charge = []
      end
      to_charge.push(invoice)
    end
    charge_invoice_group(to_charge)
  end

  private
  
    def charge_invoice_group(invs)
      # flee if the group contains no available invoice
      return if invs.blank? || invs.find{|i| i.status == 'available' }.nil?
      # charge the invoices in the group until failure
      invs.each do |invoice|
        break unless invoice.pay(stripe_source: :default, allow_missed: true)[:success] # WARNING: remove 'break unless' if you want to keep trying even after a failure
      end
    end

    def set_invoices
      # ******************************************************* #
      # WARNING WARNING WARNING WARNING WARNING WARNING WARNING #
      # ******************************************************* #
      #                                                         #
      # Hey, you! Developer! Yes, you!                          #
      # Read. This. Before. Changing. This. Code.               #
      # YES, YOU!!!                                             #
      #                                                         #
      # The part of the join below that deals with Policy       #
      # is IMPORTANT! If a PolicyQuote's first payment          #
      # succeeds (and the invoices are thus set to 'upcoming')  #
      # but bind fails, right now those invoices will           #
      # just be sitting there waiting for payment, and will     #
      # even get set to 'available'. THAT JOIN is the only      #
      # thing standing between you and charging a bunch of      #
      # customers wrongly. DON'T REMOVE IT.                     #
      #                                                         #
      # If the aforementioned problem has already been fixed,   #
      # fine, then its only purpose is to ensure auto_pay       #
      # and policy_in_system are true.                          #
      #                                                         #
      # ******************************************************* #
      policy_ids = Policy.select(:id).policy_in_system(true).current.where(auto_pay: true).pluck(:id)
      @invoices = Invoice.where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).where(status: 'accepted', policy_id: policy_ids)).or(
                            Invoice.where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: PolicyGroupQuote.select(:id).where(status: 'accepted', policy_group_id: PolicyGroup.select(:id).policy_in_system(true).current.where(auto_pay: true)))
                         ).or(
                            Invoice.where(invoiceable_type: 'Policy', invoiceable_id: policy_ids)
                         ).where("due_date <= '#{Time.current.to_date.to_s(:db)}'").where(status: ['available'], external: false).order(invoiceable_type: :asc, invoiceable_id: :asc, due_date: :asc)
                         # MOOSE WARNING: should add back 'missed' to the status filter above that only includes 'available' now
    end
end
