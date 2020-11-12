# =Deposit Choice Policy Application Functions Concern
# file: +app/models/concerns/carrier_dc_policy_application.rb+

module CarrierDcPolicyApplication
  extend ActiveSupport::Concern

  included do
  
    def dc_estimate(quote_id = nil)
		  quote = quote_id.nil? ? policy_quotes.create!(agency: agency, account: account) : 
		                          policy_quotes.find(quote_id)
      quote.update(status: 'estimated')
      return quote
    end

	  
	  # DC Quote
	  # 
	  # Takes Policy Application data and 
	  # sends to Deposit Choice to create a quote
	  
	  def dc_quote(quote_id = nil)
    
      quote_success = false
      status_check = self.complete? || self.quote_failed?
      quote = quote_id ? self.policy_quotes.find(quote_id) : self.dc_estimate
    
      if status_check && self.carrier_id == DepositChoiceService.carrier_id
        # get unit
        unit = self.primary_insurable
        unit_profile = unit.carrier_profile(self.carrier_id)
        # get rates
        result = unit.dc_get_rates(self.effective_date)
        # make sure we succeeded
        unless result[:success]
          puts "Deposit Choice Rate Retrieval Failure (#{result[:error]}), Event ID: #{ result[:event].id }"
          quote.mark_failure()
          return false
        end
        # make sure we've chosen a valid rate
        chosen = result[:rates].find{|r| r["bondAmount"] == self.coverage_selections&.[]("bondAmount") }
        if chosen.nil?
          puts "Deposit Choice Rate Retrieval Failure (Invalid Bond Amount '#{self.coverage_selections&.[]("bondAmount") || 'N/A'}')"
          quote.mark_failure()
          return false
        end
        # build policy premium
        premium = PolicyPremium.new(
          base: chosen["ratedPremium"],
          taxes: 0,
          external_fees: chosen["processingFee"],
          only_fees_internal: true,
          billing_strategy: self.billing_strategy,
          policy_quote: quote
        )
        premium.set_fees
        premium.calculate_fees(true)
        premium.calculate_total(true)
        # finalize quote
        quote_method = premium.save ? "mark_successful" : "mark_failure"
        quote.send(quote_method)
        if quote.status != 'quoted'
          puts "\nQuote Save Error\n"
          pp quote.errors
          return false
        else
          # generate internal invoices
          #quote.generate_invoices_for_term MOOSE WARNING: uncomment if there are ever internal ones...
          # generate external invoices
          quote.invoices.create!({
            external: true,
            status: "quoted",
            payer: self.primary_user,
            due_date: Time.current.to_date,
            available_date: Time.current.to_date,
            term_first_date: self.effective_date,
            term_last_date: self.expiration_date,
            line_items_attributes: [
              {
                title: "Premium",
                price: premium.base,
                refundability: 'no_refund', # MOOSE WARNING: really?
                category: 'base_premium'
              },
              {
                title: "Processing Fee",
                price: premium.external_fees,
                refundability: 'no_refund',
                category: 'deposit_fees'
              }
            ]
          })
          return true
        end
      end
    end
    
    
  end
end
