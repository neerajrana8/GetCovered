# Get Covered Account Seed Setup File
# file: db/seeds/account.rb

require './db/seeds/functions'
require 'faker'
require 'socket'

# Setting up some random company names
@random_company_names = []
6.times do
	@random_company_names << Faker::Company.name
end

# Setting up some fake company addresses
@addresses = [
	{
		street_number: "3201",
		street_name: "S. Bentley Ave",
		city: "Los Angeles",
		state: "CA",
		county: "LOS ANGELES",
		zip_code: "90034",
		primary: true
	},
	{
		street_number: "1661",
		street_name: "Bundy Dr",
		city: "Los Angeles",
		state: "CA",
		county: "LOS ANGELES",
		zip_code: "90025",
		primary: true
	},
	{
		street_number: "5145",
		street_name: "Yarmouth Ave",
		city: "ENCINO",
		state: "CA",
		county: "LOS ANGELES",
		zip_code: "91316",
		primary: true
	},
  {
    street_number: "105",
    street_name: "N Elm St",
    city: "Mahomet",
    county: "Champaign",
    state: "IL",
    zip_code: "61853",
    plus_four: "9364",
    primary: true
  },
  {
    street_number: "1514",
    street_name: "Robin St",
    city: "Auburndale",
    county: "Polk",
    state: "FL",
    zip_code: "33823",
    plus_four: "9718",
    primary: true
  },
  {
    street_number: "3201",
    street_name: "S Bentley Ave",
    city: "Los Angeles",
    county: "LOS ANGELES",
    state: "CA",
    zip_code: "90034",
    plus_four: "5203",
    primary: true
  }
]

@agencies = Agency.all
@agencies.each_with_index do |agency, index|
		
	2.times do
		account_count = Account.count
		account = agency.accounts.new(title: @random_company_names[account_count], 
																	enabled: true, 
																	whitelabel: true, 
																	tos_accepted: true, 
																	tos_accepted_at: Time.current, 
																	tos_acceptance_ip: Socket.ip_address_list.select{ |intf| intf.ipv4_loopback? }, 
																	verified: true, 
																	stripe_id: nil,
																	addresses_attributes: [@addresses[account_count]])
																				
			if account.save
			  site_staff = [
			    { email: "dylan@#{ account.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: account, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
			    { email: "brandon@#{ account.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: account, profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }}
			  ]
			  
			  site_staff.each do |staff|
			    SeedFunctions.adduser(Staff, staff)
			  end

# 		  Working on a fix for stipe connect integration 8/1/19 - Dylan
#			  account.create_stripe_connect_account	
# 			  
# 			  account.validate_stripe_connect_account({ 
# 			  	:business_tax_id => "82-3427840", 
# 			  	:business_name => account.title, 
# 			  	:personal_id_number => "406847092", 
# 			  	:file => "/db/seeds/assets/demo-card.jpg",
# 			  	:ip_address => '127.0.0.1'
# 				 })
# 				 
# 			  account.add_external_account({ 
# 				  :object => 'bank_account', 
# 				  :country => 'US', 
# 				  :currency => 'usd', 
# 				  :routing_number => '110000000', 
# 				  :account_number => '000123456789' 
# 				})
# 			
# 			  account.stripe_account_verification_status()		  
			  
			end
		end
	
end