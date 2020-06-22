# =MSI Policy Application Functions Concern
# file: +app/models/concerns/carrier_msi_policy.rb+

module CarrierMsiPolicyApplication
  extend ActiveSupport::Concern

  included do
	  
	  # MSI Estimate
	  # 
	  
	  def msi_estimate(quote_id = nil)
			
		  quote = quote_id.nil? ? policy_quotes.create!(agency: agency, account: account) : 
		                          policy_quotes.find(quote_id)
      return quote
                              
      # There's no need to bother calling GetFinalPremium an extra time here, just do it in msi_quote
      #
      #if quote.persisted?
      #  result = ::InsurableRateConfiguration.get_coverage_options(
      #    self.carrier_id,
      #    self.primary_insurable.carrier_profile(5),
      #    self.coverage_selections || [],
      #    self.effective_date,
      #    self.users.count - 1
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
      quote = quote_id ? self.policy_quotes.find(quote_id) : self.msi_estimate # MOOSE WARNING: create quote if nil or reinstate: raise ArgumentError, 'Argument "quote_id" cannot be nil' if quote_id.nil?
    
      if status_check && self.carrier == ::Carrier.find_by_call_sign('MSI')
        # grab some values
        unit = self.primary_insurable
        unit_profile = unit.carrier_profile(self.carrier_id)
        community = unit.parent_community
        community_profile = community.carrier_profile(self.carrier_id)
        address = unit.primary_address
        carrier_agency = CarrierAgency.where(agency_id: self.account.agency_id, carrier_id: self.carrier_id).take
        # call getfinalpremium
        if community_profile.data['registered_with_msi'] == true # MOOSE WARNING: do we also want an ho4_enabled setting for msi after all?
          self.update(status: 'quote_in_progress')
          # validate & make final premium call to msi
          results = ::InsurableRateConfiguration.get_coverage_options(
            5, # msi id
            community_profile,
            self.coverage_selections,
            self.effective_date,
            self.users.count - 1,
            eventable: quote # by passing a PolicyQuote we ensure results[:msi_data] & results[:event] get passed back out
          )
          # make sure we succeeded
          if !results[:valid]
            puts "\MSI Coverage Validation Or FinalPremium Request Unsuccessful, Errors: #{ results[:errors][:internal] }, Event ID: #{ event.id }"
            quote.mark_failure()
            return false
          elsif results[:msi_data][:error] # just in case
            puts "\MSI FinalPremium Request Unsuccessful, Errors: #{ results[:errors][:internal] }, Event ID: #{ event.id }"
            quote.mark_failure()
            return false
          else
            # grab msi payment amounts
            payment_plan = self.billing_strategy.carrier_code
            installment_count = MsiService::INSTALLMENT_COUNT[payment_plan]
            if installment_count.nil?
              puts "\MSI Missing Installment Count, Payment Plan Carrier Code: '#{payment_plan}', Event ID: #{ event.id }"
              quote.mark_failure()
              return false
            end
            policy_data = msi_data[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "PersPolicy")
            product_uid = policy_data["CompanyProductCd"]
            msi_policy_fee = policy_data["MSI_PolicyFee"] # not sure how this fits into anything
            payment_data = policy_data["PaymentPlan"].find{|pp| pp["PaymentPlanCd"] = payment_plan }
            if payment_data.nil?
              puts "\MSI FinalPremium PaymentData Nonexistent, Payment Plan Carrier Code: '#{payment_plan}', Event ID: #{ event.id }"
              quote.mark_failure()
              return false
            end
            reading = "MSI_TotalPremiumAmt"
            begin
              reading = "MSI_TotalPremiumAmt"
              total_paid = (payment_data.dig("MSI_TotalPremiumAmt", "Amt").to_d * 100).ceil                 # the total amount paid to msi
              reading = "MSI_InstallmentPaymentAmount"
              total_installment = (payment_data.dig("MSI_InstallmentPaymentAmount", "Amt").to_d * 100).ceil # the total amount paid at each installment, excluding the first
              reading = "MSI_InstallmentFeeAmount"
              fee_installment = (payment_data.dig("MSI_InstallmentFeeAmount", "Amt").to_d * 100).ceil       # how much of the installment total is a fee (excluding the first)
              reading = "MSI_InstallmentAmount"
              premium_installment = (payment_data.dig("MSI_InstallmentAmount", "Amt").to_d * 100).ceil      # how much of the installment total is not a fee (excluding the first)
              reading = "MSI_DownPaymentAmount"
              down_payment = (payment_data.dig("MSI_DownPaymentAmount", "Amt").to_d * 100).ceil             # the total amount of the first payment
            rescue NoMethodError => e
              puts "\MSI FinalPremium PaymentData Missing Field '#{reading}', Payment Plan Carrier Code: '#{payment_plan}', Event ID: #{ event.id }"
              quote.mark_failure()
              return false
            end
            # build policy premium
            ############# MOOSE WARNING: currently no support for EXTERNAL 'invoices'; all of this will be charged on invoice!!!! ##########
            premium = PolicyPremium.new(
              base: down_payment + premium_installment * installment_count,
              taxes: 0,
              amortized_fees: fee_installment * installment_count,
              billing_strategy: self.billing_strategy,
              policy_quote: quote
            )
            premium.set_fees
            premium.calculate_fees(true)
            # woot
            quote_method = premium.save ? "mark_successful" : "mark_failure"
            quote.send(quote_method)
            if quote.status == 'quoted'
              quote.generate_invoices_for_term
              return true
            else
              puts "\nQuote Save Error\n"
              pp quote.errors
              return false
            end
          end
        end
      end
      
    end
    
    
    
  end
end
