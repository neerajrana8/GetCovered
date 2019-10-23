@leases = Lease.where(lease_type_id: 1)

@leases.each do |lease|
	if rand(0..100) > 33 # Create a 66% Coverage Rate
		
		policy_type = PolicyType.find(1)
		billing_strategy = BillingStrategy.where(agency: lease.account.agency, policy_type: policy_type)
		                                  .order("RANDOM()")
		                                  .take
		
		application = PolicyApplication.new(
			effective_date: lease.start_date,
			expiration_date: lease.end_date,
			carrier_id: 1,
			policy_type: policy_type,
			billing_strategy: billing_strategy,
			agency: lease.account.agency,
			account: lease.account
		)
		
		application.insurables << lease.insurable
		
		if application.save()
			community = lease.insurable.insurable
			application.insurables << lease.insurable
			lease.users.each { |u| application.users << u }
			
			application.policy_application_answers.each do |answer|
				
				# Set Number of Insured on applicable
				# Policy Application Answer
				if answer.policy_application_field_id == 1
					answer.data['answer'] = application.users.count 
					answer.save()
				end
				
			end
		  
		  # If application is set as complete
      if application.update status: 'complete'
					
				florida_check = application.primary_insurable().insurable.primary_address().state == "FL" ? true : false
	      deductibles = florida_check ? [50000, 100000] : [25000, 50000, 100000]
	      hurricane_deductibles = florida_check ? [50000, 100000, 250000, 500000] : nil 
	      
	      deductible = deductibles[rand(0..(deductibles.length - 1))]
	      
	      interval = rand(0..3)
	      
	      if florida_check == true
	        hurricane_deductible = 0
	        while hurricane_deductible < deductible
	          hurricane_deductible = hurricane_deductibles[rand(0..(hurricane_deductibles.length - 1))]
	        end
	      else
	        hurricane_deductible = nil
	      end

				query = florida_check ? "(deductibles ->> 'all_peril')::integer = #{ deductible } AND (deductibles ->> 'hurricane')::integer = #{ hurricane_deductible } AND number_insured = #{ lease.users.count } AND interval = #{ interval }" :	"(deductibles ->> 'all_peril')::integer = #{ deductible } AND number_insured = #{ lease.users.count } AND interval = #{ interval }"      

				coverage_c_rates = community.insurable_rates
				                            .activated
				                            .coverage_c
				                            .where(query)
				
				liability_rates = community.insurable_rates
				                           .activated
				                           .liability
				                           .where(number_insured: lease.users.count, interval: interval.to_s)
	      
	      # Checking necessary rates have been found
	      unless coverage_c_rates.blank? || liability_rates.blank?
		      		 
	        coverage_c_rate = coverage_c_rates[rand(0..(coverage_c_rates.count - 1))]
	        liability_rate = liability_rates[rand(0..(liability_rates.count - 1))]		      					

					application.qbe_estimate([coverage_c_rate, liability_rate])
					quote = application.policy_quotes.first
					
					# Quoting Policy Application
					if application.status != "quote_failed" || application.status != "quoted"
						application.qbe_quote(quote.id) 
						application.reload()
						quote.reload()
						
						if quote.status == "QUOTED"
  						quote.accept()
  						premium = quote.policy_premium
  						puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status } | Base: $#{ '%.2f' % (premium.base.to_f / 100) } | Taxes: $#{ '%.2f' % (premium.taxes.to_f / 100) } | Fees: $#{ '%.2f' % (premium.total_fees.to_f / 100) } | Total: $#{ '%.2f' % (premium.total.to_f / 100) }"
						else
						  puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status }"
						end            
          end
          # End Quoting Policy Application
           
				end
	      # End Cgecjubg necessary rates have been found

		  end
		  # End If application is set as complete
			
		else
			pp application.errors	
		end
			
	end	
end