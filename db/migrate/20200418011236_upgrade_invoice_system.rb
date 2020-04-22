class UpgradeInvoiceSystem < ActiveRecord::Migration[5.2]
  def up
    # add proration_reduction & active_dispute_count to Invoice
    add_column :invoices, :proration_reduction, :integer, null: false, default: 0
    add_column :invoices, :disputed_charge_count, :integer, null: false, default: 0
    add_column :invoices, :was_missed, :boolean, null: false, default: false
    
    # fix up policy billing dispute fields
    change_column_default :policies, :billing_dispute_count, 0
    change_column_default :policies, :billing_dispute_status, 0
    change_column_null :policies, :billing_dispute_count, false
    change_column_null :policies, :billing_dispute_status, false
    
    # add line item columns
    add_column :line_items, :refundability, :integer, null: false
    add_column :line_items, :category, :integer, null: false, default: 0
    add_column :line_items, :priced_in, :boolean, null: false, default: false
    
    # add line items themselves
    ::Invoice.group("invoiceable_type, invoiceable_id").pluck("invoiceable_type, invoiceable_id").each do |invoiceable|
      # get PolicyQuote
      policy_quote = nil
      invoices = nil
      case invoiceable[0]
        when 'PolicyQuote'
          policy_quote = ::PolicyQuote.find(invoiceable[1])
        when 'Policy'
          policy_quote = ::Policy.find(invoiceable[1]).policy_quotes.accepted.take
      end
      if policy_quote.nil?
        raise "Migration failed: invoiceable type '#{invoiceable[0]}' is unknown! Please modify the UpgradeInvoiceSystem migration's up method to add instructions for deriving policy information from this type."
      else
        invoices = ::Invoice.where(invoiceable_type: invoiceable[0], invoiceable_id: invoiceable[1]).order("due_date ASC")
      end
      # add line items
      create_invoice_line_items(policy_quote, invoices)
    end
    ::Invoice.all.each do |inv|
      # subtotal used to be total - fees; now it is total - proration_reduction, which is 0
      inv.update_columns(subtotal: inv.total, proration_reduction: 0)
    end
  end
  
  
  def down
    ::Invoice.all.each do |inv|
      # restore subtotal to total - fees instead of total - proration_reduction
      inv.update_columns(subtotal: inv.line_items.where(refundability: 'prorated_refund').inject(0){|sum,li| sum + li.price })
    end
    ::LineItem.all.delete_all
    
    remove_column :line_items, :priced_in
    remove_column :line_items, :category
    remove_column :line_items, :refundability
    remove_column :invoices, :was_missed
    remove_column :invoices, :disputed_charge_count
    remove_column :invoices, :proration_reduction
  end
  
  private
  
    # this is for the up migration, to create line items where none existed;
    # MOOSE WARNING: this will NOT function correctly for invoiceables other than PolicyQuote or Policy; these don't exist in the database right now anyway, see the "get PolicyQuote" switch statement in the up migration
    def create_invoice_line_items(policy_quote, invoices)
      invoice_array = invoices.to_a.sort{|a,b| a.due_date <=> b.due_date }
      # get info from policy application
      billing_plan = {
        billing_schedule: policy_quote.policy_application.billing_strategy.new_business['payments'],
        effective_date: policy_quote.policy_application.effective_date,
        payee: policy_quote.policy_application.primary_user
      }
      policy_premium = policy_quote.policy_premium
      # calculate sum of weights
      payment_weight_total = billing_plan[:billing_schedule].inject(0){|sum,p| sum + p }.to_d
      payment_weight_total = 100.to_d if payment_weight_total <= 0
      # setup
      roundables = [:deposit_fees, :amortized_fees, :base, :special_premium, :taxes] # fields on PolicyPremium to have rounding errors fixed
      refundabilities = { base: 'prorated_refund', special_premium: 'prorated_refund', taxes: 'prorated_refund' } # fields that can be refunded on cancellation
      line_item_names = { base: "Premium", special_premium: "Special Premium" } # fields to rename on the invoice
      line_item_categories = { base: "base_premium", special_premium: "special_premium", taxes: "taxes", deposit_fees: "deposit_fees", amortized_fees: "amortized_fees" }
      # flee if incomprehensible error occurs
      payments = billing_plan[:billing_schedule].select{|p| p > 0 }
      if payments.length != invoice_array.length
        raise "Migration failed: there are #{invoice_array.length} invoices for #{invoices.first.invoiceable_type} ##{invoices.first.invoiceable_id}, but the billing schedule has only #{payments.length} pay periods"
      end
      # calculate invoice charges
      to_charge = invoice_array.map.with_index do |invoice, index|
        payment = payments[index]
        {
          invoice: invoice,
          deposit_fees: (index == 0 ? policy_premium.deposit_fees : 0),
          amortized_fees: (policy_premium.amortized_fees * payment / payment_weight_total).floor,
          base: (policy_premium.base * payment / payment_weight_total).floor,
          special_premium: (policy_premium.special_premium * payment / payment_weight_total).floor,
          taxes: (policy_premium.taxes * payment / payment_weight_total).floor
        }
      end.map{|tc| tc.merge({ total: roundables.inject(0){|sum,r| sum + tc[r] } }) }
      # add any rounding errors to the first charge
      roundables.each do |roundable|
        to_charge[0][roundable] += policy_premium.send(roundable) - to_charge.inject(0){|sum,tc| sum + tc[roundable] }
      end
      to_charge[0][:total] = roundables.inject(0){|sum,r| sum + to_charge[0][r] }
      # calculate discrepancies between invoice totals and what the totals WOULD be if we generated them now; create a discrepancies hash to keep track as we move cents around
      to_charge.each{|tc| tc[:invoice_extra] = tc[:invoice].total - tc[:total] }
      if to_charge.inject(0){|sum,tc| sum + tc[:invoice_extra] } != 0
        raise "Migration failed: invoices for #{invoices.first.invoiceable_type} ##{invoices.first.invoiceable_id} have non-canceling discrepancies from the line item prices for this policy as they would be calculated now."
      end
      discrepancies = roundables.select{|roundable| roundable != :deposit_fees && (roundable != :special_premium || policy_premium.special_premium > 0) && policy_premium.send(roundable) != 0 }.map do |roundable|
        [
          roundable,
          0
        ]
      end.to_h
      #adjust for discrepancies
      to_charge.select{|tc| tc[:invoice_extra] < 0 }.each do |tc| # first handle negative discrepancies
        (0...(-tc[:invoice_extra])).each do |n|
          roundable = discrepancies.select{|k,v| !tc[k].nil? && tc[k] > 0 }.sort{|a,b| a[1].to_d / policy_premium.send(a[0]) <=> b[1].to_d / policy_premium.send(b[0]) }.last[0] # they're all nonpositive, so the greatest has the least absolute value
          tc[roundable] -= 1
          discrepancies[roundable] -= 1
        end
        tc[:invoice_extra] = 0
      end
      to_charge.select{|tc| tc[:invoice_extra] > 0 }.each do |tc| # then we handle positive discrepancies
        (0...tc[:invoice_extra]).each do |n|
          roundable = discrepancies.select{|k,v| !tc[k].nil? }.sort{|a,b| a[1].to_d / policy_premium.send(a[0]) <=> b[1].to_d / policy_premium.send(b[0]) }.first[0] # they're all nonpositive, so the least has the greatest absolute value
          tc[roundable] += 1
          discrepancies[roundable] += 1
        end
        tc[:invoice_extra] = 0
      end
      if to_charge.any?{|tc| tc[:invoice_extra] != 0 }
        # literally impossible to run, but I'd rather find out I coded something wrong by getting an impossible error message than by messing up live invoices
        raise "Migration failed: invoices for #{invoices.first.invoiceable_type} ##{invoices.first.invoiceable_id} have discrepancies from new-style line item calculation that inexplicably failed to cancel"
      end
      # create line items
      to_charge.each do |tc|
        tc[:invoice].line_items.create!((roundables + [:additional_fees]).map do |roundable|
            {
              title: line_item_names[roundable] || roundable.to_s.titleize,
              price: tc[roundable] || 0,
              refundability: refundabilities[roundable] || 'no_refund',
              category: line_item_categories[roundable] || 'uncategorized',
              priced_in: true
            }
          end.select{|lia| !lia.nil? && lia[:price] > 0 }
        )
      end
    end
end
