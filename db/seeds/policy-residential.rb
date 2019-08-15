@leases = Lease.where(lease_type_id: 1)\

@leases.each do |lease|
	if rand(0..100) > 33 # Create a 66% Coverage Rate
		
		application = PolicyApplication.new(
			effective_date: lease.start_date,
			expiration_date: lease.end_date,
			carrier_id: 1,
			policy_type_id: 1,
			agency: lease.account.agency,
			account: lease.account,	
		)
		
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
		      
		      unless coverage_c_rates.blank? || liability_rates.blank?
			      		 
		        coverage_c_rate = coverage_c_rates[rand(0..(coverage_c_rates.count - 1))]
		        liability_rate = liability_rates[rand(0..(liability_rates.count - 1))]		      					
	
						application.qbe_estimate([coverage_c_rate, liability_rate])
						quote = application.policy_quotes.first
						if application.qbe_quote(quote.id)
							puts "#{ application.id } : #{ application.status } : #{ application.primary_insurable().title } at #{ application.primary_insurable().insurable.title } : #{ application.primary_insurable().primary_address().state }"
						end
					end
				end
				
			end
		else
			pp application.errors	
		end
			
	end	
end