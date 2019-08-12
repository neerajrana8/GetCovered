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
					if application.quote()
						puts "#{ application.id } : #{ application.status } : #{ application.primary_insurable().title } at #{ application.primary_insurable().insurable.title } : #{ application.primary_insurable().primary_address().state }"
					end
				end
				
			end
		else
			pp application.errors	
		end
			
	end	
end