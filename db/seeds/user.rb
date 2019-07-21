# User Setup File
# file: db/seeds/user.rb

require 'faker'

def adduser(user_type, chash)
  @user = user_type.new(chash)
  @user.invite! do |u|
    u.skip_invitation = true
  end
  token = Devise::VERSION >= "3.1.0" ? @user.instance_variable_get(:@raw_invitation_token) : @user.invitation_token
  user_type.accept_invitation!({invitation_token: token}.merge(chash))
  @user
end

@units = Insurable.residential_units
@units.each do |unit|
  
  # Create a 66% Occupancy Rate
  occupied_chance = rand(0..100)
  if occupied_chance > 33
    
    tenant_count = rand(1..5)
		start_date = (Time.now + rand(0..90).days).change(day: 1)
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
	        
	        unless User.exists?(:email => email)
				  	@lease.users << User.create!(email: email, password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234',
				  													     profile_attributes: { first_name: name[:first], last_name: name[:last] })		
	        	break        
		      end

	      end
		  end
		  
		else
		
			pp @lease.errors
		    
	  end
    
    
  end
end

puts "\nOccupancy Rate: #{ (Lease.count.to_f / Insurable.residential_units.count) * 100 }%\n"