class UpgradeOldFinanceData < ActiveRecord::Migration[5.2]
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def up
    dictionary = {}
    # Policy Premia
    ArchivedPolicyPremium.all.each do |old|
      pq = old.policy_quote
      pa = pq.policy_application
      # create PolicyPremium
      total_premium = old.base + (old.include_special_premium ? old.special_premium : 0)
      total_tax = old.taxes
      total_fee = old.total_fees
      prorated = !pq.policy.nil? && pq.policy.status == 'CANCELLED'
      premium = {
        policy_quote_id: pq_id,
        billing_strategy_id: old.billing_strategy_id,
        policy_id: old.policy_id,
        commission_strategy_id: pa.carrier_agency_authorization.commission_strategy_id,
        created_at: old.created_at,
        updated_at: old.updated_at,
        total_premium: total_premium,
        total_tax: total_tax,
        total_fee: total_fee,
        total: total_premium + total_tax + total_fee,
        prorated: prorated,
        prorated_term_first_moment: !prorated ? nil : pq.policy.effective_date.beginning_of_day,
        prorated_term_last_moment: !prorated ? nil : pq.policy.cancellation_date.end_of_day,
        force_no_refunds: false,
        error_info: nil
      }
      premium = PolicyPremium.create!(premium)
      # create PolicyPremiumPaymentTerms (and grab invoice and line item arrays while we're at it)
      invoices = pq.invoices.order(term_first_date: :asc).to_a
      if invoices.blank?
        puts "Policy premium ##{old.id} failed the sanity check; it has no invoices!"
        raise Exception
      end
      line_items = ::ArchivedLineItem.where(invoice_id: invoices.map{|i| i.id }).to_a
      pppts = invoices.map do |inv|
        ::PolicyPremiumPaymentTerm.create!(
          policy_premium: premium,
          first_moment: inv.term_first_date.beginning_of_day,
          last_moment: inv.term_last_date.end_of_day,
          time_resolution: 'day',
          default_weight: 1,
          term_group: nil
        )
      end
      # create new invoices (but no line items yet)
      new_invoices = invoices.map.with_index do |inv, ind|
        to_create = ::Invoice.new(
          number: inv.number,
          description: inv.description,
          available_date: inv.available_date,
          due_date: inv.due_date,
          external: false,
          status: ############# MOOSE WARNING map invoice status,
          under_review: false,
          pending_charge_count: ####### ugh figure out how to get this,
          pending_dispute_count: 0,
          error_info: [],
          was_missed: inv.was_missed,
          was_missed_at: !inv.was_missed ? nil : inv.status == 'missed' ? inv.status_changed : (inv.due_date + 1.day).beginning_of_day,
          autosend_status_change_notifications: true,
          # due stuff
          original_total_due: inv.subtotal,
          total_due: inv.total,
          total_payable: inv.total,
          total_reducing: 0, # MOOOSESE
          total_pending: 0, # MOOESSSSEE
          total_received:  #############
          total_undistributable:## 
          # assocs
          invoiceable: pq,
          payer: pa.primary_user,
          collector: ::PolicyPremium.default_collector
        )
        to_create.callbacks_disabled = true
        to_create.save!
      end
      # create PolicyPremiumItems and PolicyPremiumItemPaymentTerms
      case pa.carrier_id
        when 1,2,3,4
          # fee calculations
          deposit_fees = old.fees.where(amortize: false, per_payment: false, enabled: true).to_a
          amortized_fees = old.fees.where(amortize: true).or(old.fees.where(per_payment: true)).where(enabled: true).to_a
          # sanity check
          deposit_fees_total = deposit_fees.inject(0){|sum,fee| sum + (fee.FLAT? ? fee.amount : (fee.amount / 100.to_d * old.combined_premium).floor) }
          amortized_fees_total = amortized_fees.inject(0){|sum,fee| sum + ((fee.FLAT? ? fee.amount : fee.amount / 100.to_d * old.combined_premium)*(fee.per_payment ? invoices.count : 1)).floor }
          if deposit_fees_total != old.deposit_fees
            puts "Policy premium ##{old.id} failed the sanity check; deposit fees are #{old.deposit_fees}, but we expected #{deposit_fees_total}"
            raise Exception
          elsif amortized_fees_total != old.amortized_fees
            puts "Policy premium ##{old.id} failed the sanity check; amortized fees are #{old.amortized_fees}, but we expected #{amortized_fees_total}"
            raise Exception
          elsif (tempster = line_items.select{|li| li.category == 'deposit_fees' }.inject(0){|sum,li| sum+li.price }) != deposit_fees_total
            puts "Policy premium ##{old.id} failed the sanity check; deposit fees are #{old.deposit_fees}, but total of deposit fee line items is #{tempster}"
            raise Exception
          elsif (tempster = line_items.select{|li| li.category == 'amortized_fees' }.inject(0){|sum,li| sum+li.price }) != amortized_fees_total
            puts "Policy premium ##{old.id} failed the sanity check; amortized fees are #{old.amortized_fees}, but total of amortized fee line items is #{tempster}"
            raise Exception
          end
          # create deposit fee PPIs
          deposit_ppis = deposit_fees.map do |fee|
            ::PolicyPremiumItem.create!(
              policy_premium: premium,
              title: fee.title || "#{(fee.amortize || fee.per_payment) ? "Amortized " : ""} Fee",
              category: "fee",
              rounding_error_distribution: "first_payment_simple",
              total_due: (fee.FLAT? ? fee.amount : (fee.amount / 100.to_d * old.combined_premium).floor),
              proration_calculation: 'payment_term_exclusive',
              proration_refunds_allowed: false,
              recipient: fee.ownerable,
              collector: ::PolicyPremium.default_collector,
              policy_premium_item_payment_terms: [
                ::PolicyPremiumItemPaymentTerm.new(
                  policy_premium_payment_term: pppts.first,
                  weight: 1
                )
              ]
            )
          end
          old_lis = line_items.select{|li| li.invoice_id == invoices.first.id && li.category == 'deposit_fees' } # for these carriers there will always be only one with title "Deposit Fees"
          oli_received = old_lis.inject(0){|sum,li| sum + li.total_received } # we can disregard li.proration_reduction since none of our fees are ever prorated
          deposit_ppis.each do |dppi|
            dppi.policy_premium_item_commissions.update_all(status: 'active') if invoices.any?{|inv| inv.status != 'quoted' }
            ppipt = dppi.policy_premium_item_payment_terms.first
            received = [oli_received, ddpi.total_due].min
            oli_received -= received
            li = ::LineItem.create!(chargeable: ppipt, title: dppi.title, priced_in: true, analytics_category: "policy_#{dppi.category}", policy_quote: pq,
              original_total_due: dppi.total_due,
              total_due: invoices.first.status == 'canceled' ? received : dppi.total_due,
              total_reducing: 0,
              total_received: received,
              preproration_total_due: dppi.total_due,
              duplicatable_reduction_total: 0
            ) # MOOSE WARNING: create LIC (and maybe a LIR) when ready >____>
          end
            
            
            
          
          
          
        when 5
        when 6
        else
          # MOOSE WARNING: some nils exist, don't they??? is that from missing policy_applications >____>???
      end
      
      
    end
    
  end
end




=begin

# Standalone sanity_check method to call on PolicyPremiums in the DB for convenience before the migration

def sanity_check(old)
  # fee calculations
  deposit_fees = old.fees.where(amortize: false, per_payment: false, enabled: true).to_a
  amortized_fees = old.fees.where(amortize: true).or(old.fees.where(per_payment: true)).where(enabled: true).to_a
  line_items = ::LineItem.where(invoice_id: (old.policy_quote&.invoices || []).map{|i| i.id }).to_a
  # sanity check
  deposit_fees_total = deposit_fees.inject(0){|sum,fee| sum + (fee.FLAT? ? fee.amount : (fee.amount / 100.to_d * old.combined_premium).floor ) }
  amortized_fees_total = amortized_fees.inject(0){|sum,fee| sum + ((fee.FLAT? ? fee.amount : fee.amount / 100.to_d * old.combined_premium)*(fee.per_payment ? old.policy_quote.invoices.count : 1)).floor }
  tr = {}
  tr[:deposit] = "wrong" if deposit_fees_total != old.deposit_fees
  tr[:amortized] = "wrong" if amortized_fees_total != old.amortized_fees
  if line_items.blank?
    tr[:line_items] = "missing"
  else
    tr[:li_deposit] = "wrong" if line_items.select{|li| li.category == 'deposit_fees' }.inject(0){|sum,li| sum+li.price } != deposit_fees_total && ![5,6].contain?(old.policy_quote&.policy_application&.carrier_id)
    tr[:li_amortized] = "wrong" if line_items.select{|li| li.category == 'amortized_fees' }.inject(0){|sum,li| sum+li.price } != amortized_fees_total && ![5,6].contain?(old.policy_quote&.policy_application&.carrier_id)
  end
  tr = nil if tr.blank?
  tr[:id] = old.id unless tr.nil?
  return tr
end



=end
