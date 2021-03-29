class UpgradeOldFinanceData < ActiveRecord::Migration[5.2]
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def up
    dictionary = {}
    # Policy Premia
    ArchivedPolicyPremium.all.each do |old|
      # grab useful boiz
      pq = old.policy_quote
      pa = pq&.policy_application
      caa = pa&.carrier_agency_authorization
      cpt = ::CarrierPolicyType.where(carrier_id: pa&.carrier_id, policy_type_id: pa&.policy_type_id).take
      cs = caa.commission_strategy # can't be nil if previous migrations succeeded, so don't bother checking
      if pq.nil?
        puts "Policy premium ##{old.id} is insane; it has no PolicyQuote!"
        raise Exception
      elsif pa.nil?
        puts "Policy premium ##{old.id} has insane policy quote with no PolicyApplication!"
        raise Exception
      elsif caa.nil?
        puts "Policy premium ##{old.id} has insane policy application with no CarrierAgencyAuthorization!"
        raise Exception
      elsif cpt.nil?
        puts "Policy premium ##{old.id} has insane policy application with no CarrierPolicyType!"
        raise Exception
      end
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
        total_premium: total_premium,
        total_tax: total_tax,
        total_fee: total_fee,
        total: total_premium + total_tax + total_fee,
        prorated: prorated,
        prorated_term_first_moment: !prorated ? nil : pq.policy.effective_date.beginning_of_day,
        prorated_term_last_moment: !prorated ? nil : pq.policy.cancellation_date.end_of_day,
        force_no_refunds: false,
        error_info: nil,
        created_at: old.created_at,
        updated_at: old.updated_at
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
          term_group: nil,
          created_at: old.created_at,
          updated_at: old.created_at
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
          collector: ::PolicyPremium.default_collector,
          created_at: inv.created_at,
          updated_at: inv.updated_at
        )
        to_create.callbacks_disabled = true
        to_create.save!
      end
      # create PolicyPremiumItems and PolicyPremiumItemPaymentTerms
      premium_proration_calculation: 'per_payment_term', premium_proration_refunds_allowed: true
      case pa.carrier_id
        when 1,2,3,4
          ppi_premium = ::PolicyPremiumItem.create!(
            policy_premium: premium,
            title: "Premium Installment",
            category: "premium",
            rounding_error_distribution: "first_payment_simple",
            total_due: old.combined_premium,
            proration_calculation: cpt.premium_proration_calculation,
            proration_refunds_allowed: cpt.premium_proration_refunds_allowed,
            recipient: cs,
            collector: ::PolicyPremium.default_collector,
            created_at: old.created_at,
            updated_at: old.created_at
          ) unless old.combined_premium == 0
          invoices.map.with_index do |inv, ind|
            lis = line_items.select{|li| li.invoice_id == inv.id && (li.category == 'base_premium' || li.category == 'special_premium') }
            price = lis.inject(0){|sum,li| sum + li.price }
            received = lis.inject(0){|sum,li| sum + li.total_received }
            proration_reduction = lis.inject(0){|sum,li| sum + li.proration_reduction }
            next if price == 0
            # premium
            ppipt = ::PolicyPremiumItemPaymentTerm.create!(
              policy_premium_item: ppi_premium,
              policy_premium_payment_term: pppts[ind],
              weight: price,
              created_at: inv.created_at,
              updated_at: inv.created_at
            )
            li = ::LineItem.create!(chargeable: ppipt, title: "Premium", priced_in: true, analytics_category: "policy_premium", policy_quote: pq,
              original_total_due: price,
              total_due: inv.status == 'canceled' ? received : price - proration_reduction,
              total_reducing: 0,
              total_received: received,
              preproration_total_due: price,
              duplicatable_reduction_total: 0
              created_at: inv.created_at,
              updated_at: lis.map{|l| l.updated_at }.max
            )
            inv.charges.each do |charge|
              # basic setup
              sc = ::StripeCharge.new(
                processed: true,
                invoice_aware: true,
                status: charge.status,
                status_changed_at: charge.updated_at,
                amount: charge.amount,
                amount_refunded: charge.amount_refunded, # amount_in_queued_refunds is already included in this number
                source: inv.payer.payment_profiles.where(default: true).take&.source_id,
                customer_stripe_id: inv.payer&.stripe_id,
                description: nil,
                metadata: nil,
                stripe_id: charge.stripe_id,
                error_info: charge.status == 'failed' ? charge.status_information : nil,
                client_error: charge.status == 'failed' ? { linear: ['stripe_charge_model.generic_error'] } : nil,
                created_at: charge.created_at,
                updated_at: charge.updated_at,
                invoice_id: new_invoices[ind]
              )
              sc.callbacks_disabled = true
              unless sc.stripe_id.nil?
                from_stripe = (::Stripe:Charge::retrieve(sc.stripe_id) rescue nil)
                unless from_stripe.nil?
                  sc.source = from_stripe['source']&.[]('id')
                  sc.description = from_stripe['description']
                  sc.metadata = from_stripe['metadata'].to_h
                end
              end
              # status-based handling
              case charge.status
                when 'processing'
                  puts "Charge ##{charge.id} is still 'processing'; we dare not upgrade until it completes!"
                  raise Exception
                when 'failed'
                  sc.save!
                when 'pending'
                  sc.save!
                when 'succeeded'
                  sc.save!
                  ::LineItemChange.create!(
                    field_changed: 'total_received',
                    amount: li.total_received,
                    handled: false,
                    line_item: li,
                    reason: sc,
                    handler: nil,
                    created_at: charge.updated_at,
                    updated_at: charge.updated_at
                  )
                  charge.refunds.each do |refund|
                    refund.full_reason ||= "Refund" # just in case it was nil, since that won't fly no more
                    new_refund = ::Refund.create!(
                      refund_reasons: [refund.full_reason],
                      amount: refund.amount,
                      amount_refunded: refund.amount,
                      amount_returned_by_dispute: 0,
                      complete: true,
                      invoice: inv,
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                    stripe_refund = ::StripeRefund.create!(
                      status: case refund.status
                        when 'processing';                    'awaiting_execution'
                        when 'queued';                        'awaiting_execution'
                        when 'pending';                       'pending'
                        when 'succeeded';                     'succeeded'
                        when 'succeeded_via_dispute_payout':  'succeeded'
                        when 'failed';                        'failed'
                        when 'errored';                       'errored'
                        when 'failed_and_handled';            refund.stripe_status == 'succeeded' ? 'succeeded' : 'succeeded_manually'
                      end,
                      full_reasons: [refund.full_reason],
                      amount: refund.amount,
                      stripe_id: refund.stripe_id,
                      stripe_reason: refund.stripe_reason,
                      stripe_status: refund.stripe_status,
                      failure_reason: refund.failure_reason,
                      receipt_number: refund.receipt_number,
                      error_message: refund.error_message,
                      refund: new_refund,
                      stripe_charge: sc,
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                    lir = ::LineItemReduction.new(
                      reason: refund.full_reason,
                      refundability: 'cancel_or_refund',
                      proration_interaction: 'shared',
                      amount_interpretation: 'max_amount_to_reduce',
                      amount: refund.amount,
                      amount_successful: refund.amount,
                      amount_refunded: refund.amount,
                      pending: false,
                      line_item: li,
                      dispute: nil,
                      refund: new_refund,
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                    lir.callbacks_disabled = true
                    lir.save!
                    ::LineItemChange.create!(
                      field_changed: 'total_received',
                      amount: -refund.amount,
                      handled: false,
                      line_item: li,
                      reason: lir,
                      handler: nil,
                      created_at: refund.created_at,
                      updated_at: refund.updated_at
                    )
                  end

              end
            end
            
            
          end
        
=begin
# fee calculations disabled since none exist in production
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
=end
            
            
          
          
          
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
