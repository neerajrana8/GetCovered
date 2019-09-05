# =QBE Policy Application Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicyApplication
  extend ActiveSupport::Concern

  included do
	  
	  # QBE Estimate
	  # 
	  
	  def qbe_estimate(rates = nil)
			raise ArgumentError, 'Argument "rates" cannot be nil' if rates.nil?
			raise ArgumentError, 'Argument "rates" must be an array' if !rates.is_a?(Array)
		  quote = policy_quotes.new(agency: agency, account: account)
		  if quote.save
				rates.each { |rate| quote.policy_rates.create!(insurable_rate: rate) }
				quote_rate_premiums = quote.insurable_rates.map { |r| r.premium.to_f }
				quote.create_policy_premium estimate: quote_rate_premiums.inject { |sum, rate| sum + rate },
																		enabled: true
			end
		end
		
		# QBE Add Policy Fee
		#
    
    def qbe_add_policy_fee
      if available_rates(:optional, :policy_fee).count > 0
        
        available_rates(:optional, :policy_fee).each do |policy_fee|
          rates << policy_fee  
        end
         
      end
    end		
	  
	  # QBE Quote
	  # 
	  # Takes Policy Application data and 
	  # sends to QBE to create a quote
	  
	  def qbe_quote(quote_id = nil)
		  quote_success = false
		  status_check = self.complete? || self.quote_failed?
		  
		  # If application complete or quote_failed 
		  # and carrier is QBE will figure out the 
		  # "I" later - Dylan August 10, 2019
		  if status_check &&
			   self.carrier == Carrier.find_by_call_sign('QBI') 
				
        unit = primary_insurable()
        unit_profile = unit.carrier_profile(carrier.id)
        community = unit.insurable
        community_profile = community.carrier_profile(carrier.id)
        address = unit.primary_address()

				if community_profile.data['ho4_enabled'] == true # If community profile is ho4_enabled
					
					quote = policy_quotes.find(quote_id) unless quote_id.nil?
					
					update status: 'quote_in_progress'
	        event = events.new(
	          verb: 'post', 
	          format: 'xml', 
	          interface: 'SOAP',
	          process: 'get_min_prem', 
	          endpoint: Rails.application.credentials.qbe[:uri]
	        )	
					
	        qbe_service = QbeService.new(:action => 'getMinPrem')
					
	        qbe_request_options = { 
	          prop_city: address.city,
	          prop_county: address.county,
	          prop_state: address.state,
	          prop_zipcode: address.combined_zip_code,
	          city_limit: community_profile.traits['city_limit'] == true ? 1 : 0,
	          units_on_site: community.insurables.count,
	          age_of_facility: community_profile.traits['construction_year'],
	          gated_community: community_profile.traits['gated_access'] == true ? 1 : 0,
	          prof_managed: community_profile.traits['professionally_managed'] == true ? 1 : 0,
	          prof_managed_year: community_profile.traits['professionally_managed_year'] == true ? "" : community_profile.traits['professionally_managed_year'],
	          effective_date: effective_date.strftime("%m/%d/%Y"),
	          premium: quote.premium.to_f / 100,
	          premium_pif: quote.premium.to_f / 100,
	          num_insured: users.count,
	          lia_amount: quote.insurable_rates.liability.first.coverage_limits["liability"].to_f / 100
	        }
	  
	        qbe_service.build_request(qbe_request_options)
	  
	        event.request = qbe_service.compiled_rxml
	  
	        if event.save # If event saves after creation
	          event.started = Time.now
	          qbe_data = qbe_service.call()
	          event.completed = Time.now
	        
		        event.response = qbe_data[:data]
		        event.status = qbe_data[:error] ? 'error' : 'success'
		        if event.save # If event saves after QBE call
			        unless qbe_data[:error] # QBE Response Success
		            xml_doc = Nokogiri::XML(qbe_data[:data])  
		            xml_min_prem = xml_doc.css('//Additional_Premium')
		            if quote_id.nil?			        
					        quote = policy_quotes.new(
										agency: agency,
										account: account,
										policy_premium_attributes: {
											base: (xml_min_prem.attribute('total_premium').value.to_f * 100).to_i,
											taxes: (xml_min_prem.attribute('tax').value.to_f * 100).to_i,
											enabled: true
										}
		 							)
		 						else
		 							
		 							quote.policy_premium.update base: (xml_min_prem.attribute('total_premium').value.to_f * 100).to_i,
		 																					taxes: (xml_min_prem.attribute('tax').value.to_f * 100).to_i
		 						end
	 							if quote.save
		 							update status: 'quoted'
		 							return true
		 						else
		 							puts "\nQuote Save Error"
		 							pp quote.errors
		 							update status: 'quote_failed'	
		 						end
		 					else # QBE Response Success Failure
		 						puts "\QBE Request Unsuccessful, Event ID: #{ event.id }"
		 						update status: 'quote_failed'
 							end # / QBE Response Success
 						else
		 					puts "\Post QBE Request Event Save Error"
 							update status: 'quote_failed'
			      end # / If event saves after QBE call
			    else
			    	update status: 'quote_failed'
					end # / If event saves after creation
				end # / If community profile is ho4_enabled
				
		  end # If application complete and carrier is QBE  	  
    end
    
  end
end