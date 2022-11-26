# User Setup File
# file: db/seeds/user.rb

require 'faker'
require './db/seeds/functions'

@residential_units = Insurable.residential_units
@residential_units.each do |unit|
  
  # Create a 33% Occupancy Rate
  occupied_chance = rand(0..100)
  if occupied_chance > 66
    
    tenant_count = rand(1..5)
		start_date = (Time.now + rand(2..16).days)
    end_date = start_date + 1.years
    
    @lease = unit.leases.new(start_date: start_date, end_date: end_date, lease_type: LeaseType.find(1), account: unit.account)
    
    if @lease.save
	  	
	  	tenant_count.times do |tc|
		  	
	      loop do
			  	name = {
				  	:first => Faker::Name.first_name,
				  	:last => Faker::Name.last_name
			  	}
			  	
			  	email_providers = ['gmail', 'yahoo', 'msn', 'outlook']
			  	email = "#{ name[:first].downcase }#{ name[:last].downcase }@#{email_providers[rand(0..3)]}.com"
	        
	        unless ::User.exists?(:email => email)
				  	user = ::User.new(email: email, password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234',
				  													     profile_attributes: { first_name: name[:first], 
					  													     										 last_name: name[:last], 
					  													     										 birth_date: SeedFunctions.time_rand(Time.local(1955, 1, 1), Time.local(1991, 1, 1)),
                                                               contact_phone: "5555555555"
                                                             })
						if user.save
              lease_user = @lease.lease_users.create(user: user, primary: (tc == 0))
              unless lease_user.id
                puts "LEASE USER FAILED LEASE USER FAILED OMG #{lease_user.errors.to_h}"
                exit
              end
            else
              puts "USER FAILED USER FAILED OMG #{user.errors.to_h}"
              exit
	        	end
	        	
	        	break        
		      end

	      end
		  end
      
      begin
        @lease.reload.primary_user.attach_payment_source("tok_visa", true)
      rescue
        puts "Well mate, everything is FUCKED."
        puts "Lease users: #{@lease.lease_users.to_a}"
        puts "Lease PU: #{@lease.primary_user}"
        throw "it's all broken"
      end
      
		else
		
			pp @lease.errors
		    
	  end
    
    
  end
end

#puts "\nOccupancy Rate: #{ (Lease.count.to_f / Insurable.residential_units.count) * 100 }%\n\n"
