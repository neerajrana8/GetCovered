# =Pensio Policy Application Functions Concern
# file: +app/models/concerns/carrier_pensio_policy_application.rb+

module CarrierPensioPolicyApplication
  extend ActiveSupport::Concern


  included do
	  
	  # Generate Quote
	  # 
	  
	  def pensio_quote  
  	  
  	  quote_success = {
    	  error: false,
    	  success: false,
    	  message: nil,
    	  data: nil
  	  }
  	  
  	  status_check = self.complete? || self.quote_failed?
  	  
		  if status_check &&
			   self.carrier == Carrier.find_by_call_sign('P') 
			
			  quote = policy_quotes.new(
					agency: self.agency,
					policy_group_quote: self.policy_application_group&.policy_group_quote
				)
			  if quote.save
				  
				  guarantee_option = self.fields["guarantee_option"].to_i

					multiplier =
						if guarantee_option == 12
							0.09
						elsif guarantee_option == 6
							0.075
						else
							0.035
						end
					
					unchecked_premium = ((( self.fields["monthly_rent"] * 100 ) * 12 ) * multiplier ).to_i
					checked_premium = unchecked_premium < 42000 ? 42000 : unchecked_premium
				  
				  premium = PolicyPremium.new base: checked_premium, policy_quote: quote, 
				                              billing_strategy: quote.policy_application.billing_strategy
				  
# 					premium.set_fees
					premium.calculate_fees(true)
					premium.calculate_total(true)			    
				  quote_method = premium.save ? "mark_successful" : "mark_failure" 
				  
				  quote.send(quote_method)
				  
				  quote_success[:success] = true
				  			  
				else
					self.update status: "quote_failed"
          quote_success[:error] = true
          quote_success[:message] = "Policy Quote failed to return"
				end
			else
        quote_success[:error] = true
				quote_success[:message] = "Application unavailable to be quoted"
			end
			
			return quote_success
			
		end
		
	end
end
