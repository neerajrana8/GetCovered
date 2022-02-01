# =MSI Policy Application Functions Concern
# file: +app/models/concerns/carrier_msi_policy_application.rb+

module CarrierMsiPolicyApplication
  extend ActiveSupport::Concern

  included do
	  
	  # MSI Estimate
	  # 
	  
	  def msi_estimate(quote_id = nil)
			
		  quote = quote_id.nil? ? policy_quotes.create!(agency: agency, account: account) : 
		                          policy_quotes.find(quote_id)
      quote.update(status: 'estimated')
      return quote
                              
      # There's no need to bother calling GetFinalPremium an extra time here, just do it in msi_quote
      #
      #if quote.persisted?
      #  result = ::InsurableRateConfiguration.get_coverage_options(
      #    self.carrier_id,
      #    self.primary_insurable.carrier_profile(5),
      #    self.coverage_selections || [],
      #    self.effective_date,
      #    self.users.count - 1,
      #    self.billing_strategy
      #  )
      #  if result[:valid] && !result[:estimated_premium].blank?
      #    quote.update(
      #      est_premium: result[:estimated_premium].values.map{|v| v.to_d }.min,
      #      status: "estimated"
      #    )
      #  end
      #end
      
		end
	  
	  # MSI Quote
	  # 
	  # Takes Policy Application data and 
	  # sends to MSI to create a quote
	  
	  def msi_quote(quote_id = nil)
    
      quote_success = false
      status_check = self.complete? || self.quote_failed?
      quote = quote_id ? self.policy_quotes.find(quote_id) : self.msi_estimate # WARNING: create quote if nil or reinstate: raise ArgumentError, 'Argument "quote_id" cannot be nil' if quote_id.nil?
    
      if status_check && self.carrier_id == ::MsiService.carrier_id
        # grab some values
        unit = self.primary_insurable
        unit_profile = unit.carrier_profile(self.carrier_id)
        community = unit.parent_community
        community_profile = community.carrier_profile(self.carrier_id)
        address = unit.primary_address
        carrier_agency = CarrierAgency.where(agency_id: self.agency_id, carrier_id: self.carrier_id).take
        carrier_policy_type = CarrierPolicyType.where(carrier_id: self.carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take
        preferred = (unit.get_carrier_status(::MsiService.carrier_id) == :preferred)
        # call getfinalpremium
        self.update(status: 'quote_in_progress')
        # validate & make final premium call to msi
        results = ::InsurableRateConfiguration.get_coverage_options(
          carrier_policy_type, unit, self.coverage_selections, self.effective_date, self.users.count - 1, self.billing_strategy,
          # execution options
          eventable: quote, # by passing a PolicyQuote we ensure results[:msi_data], results[:event], and results[:annotated_selections] get passed back out
          perform_estimate: true,
          add_selection_fields: true,
          # overrides
          additional_interest_count: preferred ? nil : self.extra_settings['additional_interest'].blank? ? 0 : 1,
          agency: self.agency,
          account: self.account,
          # nonpreferred stuff
          nonpreferred_final_premium_params: preferred ? nil : {
            address_line_two: unit.title.nil? ? nil : "Unit #{unit.title}",
            number_of_units: self.extra_settings&.[]('number_of_units'),
            years_professionally_managed: self.extra_settings&.[]('years_professionally_managed'),
            year_built: self.extra_settings&.[]('year_built'),
            gated: self.extra_settings&.[]('gated')
          }.compact
        )
        # make sure we succeeded
        if !results[:valid]
          interr = "MSI Coverage Validation Or FinalPremium Request Unsuccessful, Errors: #{ results[:errors][:internal].gsub("\n", "; ") }, Event ID: #{ results[:event].id }"
          puts interr
          quote.mark_failure(results[:errors][:external], interr)
          return false
        elsif results[:msi_data][:error] # just in case
          interr = "MSI FinalPremium Request Unsuccessful, Errors: #{ results[:errors][:internal].gsub("\n", "; ") }, Event ID: #{ results[:event].id }"
          puts interr
          quote.mark_failure(results[:errors][:external], interr)
          return false
        elsif !self.update(coverage_selections: results[:annotated_selections]) # update our coverage selections with any annotations from the get_coverage_options call
          interr = "MSI Selection Annotation Failed, Errors: #{self.errors.to_h.to_s}, Event ID: #{ results[:event].id }"
          puts interr
          quote.mark_failure("Internal Error (786)", interr)
          return false
        else
          # grab msi payment amounts
          payment_plan = self.billing_strategy.carrier_code
          installment_count = MsiService::INSTALLMENT_COUNT[payment_plan]
          if installment_count.nil?
            interr = "MSI Missing Installment Count, Payment Plan Carrier Code: '#{payment_plan}', Event ID: #{ results[:event].id }"
            puts interr
            quote.mark_failure("Internal Error (504)", interr)
            return false
          end
          policy_data = results[:msi_data][:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "PersPolicy")
          product_uid = policy_data["CompanyProductCd"]
          msi_policy_fee = ((policy_data["MSI_PolicyFee"]&.[]('Amt')&.to_d || 0) * 100).ceil
          payment_data = policy_data["PaymentPlan"].find{|ppl| ppl["PaymentPlanCd"] == payment_plan }
          if payment_data.nil?
            interr = "MSI FinalPremium PaymentData Nonexistent, Payment Plan Carrier Code: '#{payment_plan}', Event ID: #{ results[:event].id }"
            puts interr
            quote.mark_failure("Internal Error (782)", interr)
            return false
          end
          reading = "MSI_TotalPremiumAmt"
          total_paid = nil
          total_installment = nil
          fee_installment = nil
          premium_installment = nil
          down_payment = nil
          begin
            reading = "MSI_TotalPremiumAmt"
            total_paid = (payment_data.dig("MSI_TotalPremiumAmt", "Amt").to_d * 100).ceil                 # the total amount paid to msi, excluding the installment fees
            reading = "MSI_InstallmentPaymentAmount"
            total_installment = (payment_data.dig("MSI_InstallmentPaymentAmount", "Amt").to_d * 100).ceil # the total amount paid at each installment, excluding the first
            reading = "MSI_InstallmentFeeAmount"
            fee_installment = (payment_data.dig("MSI_InstallmentFeeAmount", "Amt").to_d * 100).ceil       # how much of the installment total is a fee (excluding the first)
            reading = "MSI_InstallmentAmount"
            premium_installment = (payment_data.dig("MSI_InstallmentAmount", "Amt").to_d * 100).ceil      # how much of the installment total is not a fee (excluding the first)
            reading = "MSI_DownPaymentAmount"
            down_payment = (payment_data.dig("MSI_DownPaymentAmount", "Amt").to_d * 100).ceil             # the total amount of the first payment
          rescue NoMethodError => e
            interr = "MSI FinalPremium PaymentData Missing Field '#{reading}', Payment Plan Carrier Code: '#{payment_plan}', Event ID: #{ results[:event].id }"
            puts interr
            quote.mark_failure("Internal Error (13)", interr)
            return false
          end
          # grab payment processor data
          payment_methods = {}
          policy_data["PaymentMethod"].each do |pm|
            if pm["MethodPaymentCd"] == "CreditDebit"
              payment_methods['card'] = {
                'merchant_id' => pm["MSI_PaymentMerchantID"],
                'processor_id' => pm["MSI_PaymentProcessor"],
                'method_id' => "CreditDebit"
              }
            elsif pm["MethodPaymentCd"] == "ACH"
              payment_methods['ach'] = {
                'merchant_id' => pm["MSI_PaymentMerchantID"],
                'processor_id' => pm["MSI_PaymentProcessor"],
                'method_id' => "ACH"
              }
            end
          end
          quote.update(carrier_payment_data: { 'product_id' => product_uid, 'payment_methods' => payment_methods, 'policy_fee' => msi_policy_fee, 'installment_fee' => fee_installment, 'installment_total' => total_installment })
          # get payment schedule
          installment_day = self.extra_settings&.[]('installment_day') || 1
          installment_day = 1 if installment_day < 1
          installment_day = 28 if installment_day > 28
          if installment_day != self.extra_settings&.[]('installment_day')
            self.extra_settings = (self.extra_settings || {}).merge({ 'installment_day' => installment_day })
            self.update_columns(extra_settings: self.extra_settings)
          end
          gotten_schedule = msi_get_payment_schedule(payment_plan, installment_day: installment_day)
          last_premium_installment = total_paid - (down_payment + premium_installment * (installment_count - 1))
          last_premium_installment = premium_installment if last_premium_installment < 0 || gotten_schedule.length <= 2 # should NEVER EVER happen, but letting a negative in would be much worse than overcharging by a few cents and refunding later
          # build policy premium & policy premium items
          succeeded = false
          premium = PolicyPremium.create policy_quote: quote
          ppi_policy_fee = nil
          ppi_installment_fee = nil
          ppi_down_payment = nil
          ppi_installment = nil
          begin
            ppi_policy_fee = ::PolicyPremiumItem.create!(
              policy_premium: premium,
              title: "Policy Fee",
              category: "fee",
              hidden: true,
              rounding_error_distribution: "first_payment_simple",
              total_due: msi_policy_fee,
              proration_calculation: "no_proration",
              proration_refunds_allowed: false,
              recipient: ::MsiService.carrier,
              collector: ::MsiService.carrier
            ) unless msi_policy_fee == 0
            ppi_installment_fee = ::PolicyPremiumItem.create!(
              policy_premium: premium,
              title: "Installment Fee",
              category: "fee",
              rounding_error_distribution: "first_payment_simple",
              total_due: fee_installment * installment_count,
              proration_calculation: "no_proration",
              proration_refunds_allowed: false,
              recipient: ::MsiService.carrier,
              collector: ::MsiService.carrier
            ) unless (fee_installment * installment_count) == 0
            ppi_down_payment = ::PolicyPremiumItem.create!(
              policy_premium: premium,
              title: "Premium Down Payment",
              category: "premium",
              rounding_error_distribution: "first_payment_simple",
              total_due: down_payment,
              proration_calculation: "no_proration",
              proration_refunds_allowed: false,
              recipient: premium.commission_strategy,
              collector: ::MsiService.carrier
            ) unless down_payment == 0
            installment_per = premium_installment * [installment_count - 1, 0].max + last_premium_installment
            ppi_installment = ::PolicyPremiumItem.create!(
              policy_premium: premium,
              title: "Premium Installment",
              category: "premium",
              rounding_error_distribution: "first_payment_simple",
              total_due: installment_per,
              proration_calculation: "no_proration",
              proration_refunds_allowed: false,
              recipient: premium.commission_strategy,
              collector: ::MsiService.carrier
            ) unless installment_per == 0
            premium.update_totals(persist: true)
            # generate terms
            gotten_schedule.each.with_index do |dates, ind|
              pp_pt = ::PolicyPremiumPaymentTerm.create!(
                policy_premium: premium,
                first_moment: dates[:term_first_date].beginning_of_day,
                last_moment: dates[:term_last_date].beginning_of_day,
                time_resolution: 'day',
                invoice_available_date_override: dates[:available_date],
                invoice_due_date_override: dates[:due_date],
                default_weight: 0
              )
              if ind == 0
                ::PolicyPremiumItemPaymentTerm.create!(
                  policy_premium_item: ppi_down_payment,
                  policy_premium_payment_term: pp_pt,
                  weight: down_payment - msi_policy_fee
                ) unless ppi_down_payment.nil? || (down_payment - msi_policy_fee) == 0
                ::PolicyPremiumItemPaymentTerm.create!(
                  policy_premium_item: ppi_policy_fee,
                  policy_premium_payment_term: pp_pt,
                  weight: msi_policy_fee
                ) unless ppi_policy_fee.nil? || msi_policy_fee == 0
              else
                ::PolicyPremiumItemPaymentTerm.create!(
                  policy_premium_item: ppi_installment,
                  policy_premium_payment_term: pp_pt,
                  weight: ind + 1 == gotten_schedule.length ? last_premium_installment : premium_installment
                ) unless ppi_installment.nil? || (ind + 1 == gotten_schedule.length ? last_premium_installment : premium_installment) == 0
                ::PolicyPremiumItemPaymentTerm.create!(
                  policy_premium_item: ppi_installment_fee,
                  policy_premium_payment_term: pp_pt,
                  weight: fee_installment
                ) unless ppi_installment_fee.nil? || fee_installment == 0
              end
            end
            succeeded = true
          rescue ActiveRecord::RecordInvalid => err
            interr = "Failed to create #{err.record.class.name}: #{err.record.errors.to_h}"
            puts interr
            quote.mark_failure("Internal Error (83)", interr)
            succeeded = nil
          end
          # woot
          if succeeded == true
            quote.mark_successful
          elsif succeeded == false
            interr = "Unknown Error"
            puts interr
            quote.mark_failure("Internal Error (47)", interr);
          elsif succeeded.nil?
            # do nothing, yo; we already called mark_failure in the rescue clause
          end
          if quote.status == 'quoted'
            # generate invoices
            result = quote.generate_invoices_for_term
            unless result.nil?
              puts result[:internal]
              quote.mark_failure(I18n.t(result[:external]), result[:internal])
              return false
            end
            # done
            return true
          else
            puts "\nQuote Save Error\n"
            pp quote.errors
            return false
          end
        end
      end
      
    end
    
    
    private
    
    
      def msi_get_payment_schedule(billing_code, installment_day: nil)
        # set installment day
        installment_day = Time.current.to_date.day if installment_day.nil?
        installment_day = 28 if installment_day > 28
        installment_day = 1 if installment_day < 1
        # go
        case billing_code
          when "Annual"
            # go wild
            [
              {
                due_date: Time.current.to_date + 1.day,
                available_date: Time.current.to_date,
                term_first_date: self.effective_date,
                term_last_date: self.expiration_date
              }
            ]
          when "SemiAnnual"
            # add 5 months to effective date and go to next installment day; subtract 1 month if > 165 days
            second_due = (self.effective_date + 5.months).change({ day: installment_day })
            second_due = second_due - 1.month if (second_due - self.effective_date).to_i > 165
            # go wild
            [
              {
                due_date: Time.current.to_date,
                available_date: Time.current.to_date,
                term_first_date: self.effective_date,
                term_last_date: second_due - 1.day
              },
              {
                due_date: second_due,
                available_date: second_due - 1.week,
                term_first_date: second_due,
                term_last_date: self.expiration_date
              }
            ]
          when "Quarterly"
            # add 2 months to effective date and go to next installment day; subtract 1 month if > 75 days; then add [2,3] months if left alone, or [3,3] months if subtracted
            second_due = (self.effective_date + 2.months).change({ day: installment_day })
            extra_add = 0
            if (second_due - self.effective_date).to_i > 75
              second_due = second_due - 1.month
              extra_add = 1
            end
            # go wild
            dds = [Time.current.to_date, second_due, second_due + (2 + extra_add).months, second_due + (5 + extra_add).months]
            dds.map.with_index do |dd, ind|
              {
                due_date: dd,
                available_date: dd - 1.week,
                term_first_date: (ind == 0 ? self.effective_date : dd),
                term_last_date: (ind == 3 ? self.expiration_date : dds[ind + 1] - 1.day)
              }
            end
          when "Monthly"
            # add 1 month to effective date and go to next installment day; subtract 1 month if > 50 days; then add 1 month each time
            #second_due = (self.effective_date + 1.month).change({ day: installment_day })
            #second_due = second_due - 1.month if (second_due - self.effective_date).to_i > 50
            
            # find the next occurrence of installment day after effective date, unless it's within 20 days
            second_due = self.effective_date.change({ day: installment_day })
            second_due = second_due + 1.month if second_due < self.effective_date
            second_due = second_due + 1.month if second_due <= self.effective_date + 20.days
            
            dds = (0..10).map{|n| (n == 0 ? Time.current.to_date : second_due + (n-1).months) }
            dds.map.with_index do |dd, ind|
              {
                due_date: dd,
                available_date: dd - 1.week,
                term_first_date: (ind == 0 ? self.effective_date : dd),
                term_last_date: (ind == 10 ? self.expiration_date : dds[ind + 1] - 1.day)
              }
            end
          else
            []
        end
      end
      
    
  end
end
