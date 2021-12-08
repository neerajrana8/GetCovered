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
  account_count = Account.count
  demo_account = agency.accounts.new(title: @random_company_names[account_count], 
    																 enabled: true, 
    																 whitelabel: true, 
    																 tos_accepted: true, 
    																 tos_accepted_at: Time.current, 
    																 tos_acceptance_ip: Socket.ip_address_list.select{ |intf| intf.ipv4_loopback? }, 
    																 verified: true, 
    																 stripe_id: nil,
    																 addresses_attributes: [@addresses[account_count]]) 

	if demo_account.save
    demo_account = demo_account.reload
	  site_staff = [
	    { email: "dylan@#{ demo_account.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'staff', enabled: true, organizable: demo_account, 
  	    profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
	    { email: "brandon@#{ demo_account.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'staff', enabled: true, organizable: demo_account, 
  	    profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }}
	  ]
	  
	  site_staff.each do |staff|
	    SeedFunctions.adduser(Staff, staff)
	  end
  else
    puts "FAILED TO SAVE ACCOUNT: #{demo_account.errors.to_h}"
    exit
	end

end

static_staff = { email: 'staff@getcovered.com', password: 'Test1234', password_confirmation: 'Test1234', role: 'staff', enabled: true,
                 organizable: Agency.first.accounts.first,
                 profile_attributes: { first_name: 'Staff', last_name: 'Staff', job_title: 'Staff'} }

SeedFunctions.adduser(Staff, static_staff)
