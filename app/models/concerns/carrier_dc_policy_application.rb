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
        premium = PolicyPremium.create policy_quote: quote
        unless premium.id
          puts "  Failed to create premium! #{premium.errors.to_h}"
        else
          created_fee = premium.fees.create(title: "Processing Fee", type: :ORIGINATION, amount: chosen["processingFee"], enabled: true, ownerable: ::DepositChoiceService.carrier)
          unless created_fee.id
            puts "  Failed to create fee! #{created_fee.errors.to_h}"
          else
            result = premium.initialize_all(chosen["ratedPremium"], collector: ::DepositChoiceService.carrier, filter_fees: Proc.new{|f| f.id == created_fee.id })
            unless result.nil?
              puts "  Failed to initialize premium! #{result}"
            else
              quote_method = "mark_successful"
            end
          end
        end
        # finalize quote
        quote_method = premium.save ? "mark_successful" : "mark_failure"
        quote.send(quote_method)
        if quote.status != 'quoted'
          puts "\nQuote Save Error\n"
          pp quote.errors
          return false
        else
          result = quote.generate_invoices_for_term
          unless result.nil?
            puts result[:internal] # MOOSE WARNING: [:external] contains an I81n key for a user-displayable message, if desired
            quote.mark_failure(result[:internal])
            return false
          end
          return true
        end
      end
    end
    
    
  end
end
