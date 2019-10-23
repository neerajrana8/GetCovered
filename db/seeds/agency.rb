# Get Covered Agency Seed Setup File
# file: db/seeds/agency.rb

require './db/seeds/functions'
require 'faker'
require 'socket'

# Setting up some fake company names for the extra agencies
@random_company_names = []
@random_company_names << Faker::Company.name
Faker::Config.random = Random.new(rand(1..42))
@random_company_names << Faker::Company.name


# Setting up carriers as individual instance variables
@qbe = Carrier.find(1)           # Residential Carrier
@qbe_specialty = Carrier.find(2) # Also qbe, but has to be a seperate entity for reasons i dont understand
@crum = Carrier.find(3)          # Commercial Carrier

@agencies = [
	##
	# Master Agency
	{
		title: "Get Covered", 
		enabled: true, 
		whitelabel: true, 
		tos_accepted: true, 
		tos_accepted_at: Time.current, 
		tos_acceptance_ip: nil, 
		verified: false, 
		stripe_id: nil, 
		master_agency: true,
		addresses_attributes: [
			{
				street_number: "265",
				street_name: "Canal St",
				street_two: "#205",
				city: "New York",
				state: "NY",
				county: "NEW YORK",
				zip_code: "10013",
				primary: true
			}
		]		
	}, 
	##
	# Demo Sub Residential Agency
	{
		title: @random_company_names[0], 
		enabled: true, 
		whitelabel: true, 
		tos_accepted: true, 
		tos_accepted_at: Time.current, 
		tos_acceptance_ip: nil, 
		verified: false, 
		stripe_id: nil, 
		master_agency: false,
		agency_id: 1,
		addresses_attributes: [
			{
				street_number: "3201",
				street_name: "S. Bentley Ave",
				city: "Los Angeles",
				state: "CA",
				county: "LOS ANGELES",
				zip_code: "90034",
				primary: true
			}
		]		
	}, 
	##
	# Demo Sub Commercial Agency
	{
		title: @random_company_names[1], 
		enabled: true, 
		whitelabel: true, 
		tos_accepted: true, 
		tos_accepted_at: Time.current, 
		tos_acceptance_ip: Socket.ip_address_list.select{ |intf| intf.ipv4_loopback? }, 
		verified: false, 
		stripe_id: nil, 
		master_agency: false,
		agency_id: 1,
		addresses_attributes: [
			{
				street_number: "1661",
				street_name: "Bundy Dr",
				city: "Los Angeles",
				state: "CA",
				county: "LOS ANGELES",
				zip_code: "90025",
				primary: true
			}
		]		
	}
]

##
# Create some demo staff for each agency
# and setup stripe data required for stripe connect

@agencies.each do |a|
	agency = Agency.new(a)
	if agency.save
	
	  site_staff = [
	    { email: "dylan@#{ agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: agency, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
	    { email: "brandon@#{ agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: agency, profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }},
	    { email: "nikita@#{ agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: agency, profile_attributes: { first_name: 'Nikita', last_name: 'Kiselev' }},
	    { email: "baha@#{ agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: agency, profile_attributes: { first_name: 'Baha', last_name: 'Sagadiev'}}
	  ]
	  
	  site_staff.each do |staff|
	    SeedFunctions.adduser(Staff, staff)
	  end		
	  
#		unless agency.master_agency?
#     Working on a fix for stipe connect integration 8/1/19 - Dylan
#		  agency.create_stripe_connect_account
# 
#		  
# 		  agency.validate_stripe_connect_account({ 
# 		  	:business_tax_id => "82-3427840", 
# 		  	:business_name => agency.title, 
# 		  	:personal_id_number => "406847092", 
# 		  	:file => "/db/seeds/assets/demo-card.jpg",
# 		  	:ip_address => '127.0.0.1'
# 			 })
#			 
# 		  agency.add_external_account({ 
# 			  :object => 'bank_account', 
# 			  :country => 'US', 
# 			  :currency => 'usd', 
# 			  :routing_number => '110000000', 
# 			  :account_number => '000123456789' 
# 			})
# 		
# 		  agency.stripe_account_verification_status() 			
#		end
		
	end	
end

##
# Setting up data for master agency (Get Covered)
# this includes billing and commission strategies needed
# before an agency can sell policies

@master_agency = Agency.find(1)

##
# Adding relevant carriers to master agency
# and setting up carrier agency authorizations 
# for each state

@master_agency.carriers << @qbe 
@master_agency.carriers << @qbe_specialty
@master_agency.carriers << @crum

@master_agency.carriers.each do |carrier|
	51.times do |state|
		
		@policy_type = nil
		@fee_amount = nil
		
		if carrier.id == 1
			@policy_type = PolicyType.find(1)
			@fee_amount = 1000
		elsif carrier.id == 2
			@policy_type = PolicyType.find(2)
		elsif carrier.id == 3
			@policy_type = PolicyType.find(4)
			@fee_amount = 800
		end
		
	  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
	  authorization = CarrierAgencyAuthorization.create(state: state, 
	  																									available: available, 
	  																									carrier_agency: CarrierAgency.where(carrier: carrier, agency: @master_agency).take, 
	  																									policy_type: @policy_type,
	  																									agency: @master_agency)
	  Fee.create(title: "Service Fee", 
	  					 type: :MISC, 
	  					 per_payment: true, 
	  					 amount: @fee_amount, 
	  					 amount_type: :PERCENTAGE, 
	  					 enabled: true, 
	  					 assignable: authorization, 
	  					 ownerable: @master_agency) unless @fee_amount.nil?
	end	
end

##
# QBE / Get Covered Billing & Comission Strategies

@master_agency.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe, 
                                  				policy_type: PolicyType.find(1), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @master_agency 
		                                  			}
                                  				])
                                  
@master_agency.billing_strategies.create!(title: 'Bi-Annually', enabled: true, 
		                                      new_business: { payments: [50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
		                                                      payments_per_term: 2, remainder_added_to_deposit: true },
		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @master_agency 
		                                  			}
                                  				])
                                  
@master_agency.billing_strategies.create!(title: 'Quarterly', enabled: true, 
		                                      new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @master_agency 
		                                  			}
                                  				])
                                  
@master_agency.billing_strategies.create!(title: 'Monthly', enabled: true, 
		                                      new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @master_agency 
		                                  			}
                                  				])

@master_agency.commission_strategies.create!(title: 'Get Covered / QBE Residential Commission', 
																						carrier: Carrier.find(1), 
																						policy_type: PolicyType.find(1), 
																						amount: 30, 
																						type: 0, 
																						house_override: 0)
@master_agency.commission_strategies.create!(title: 'Get Covered / QBE Producer Commission', 
																						carrier: Carrier.find(1), 
																						policy_type: PolicyType.find(1), 
																						amount: 5, 
																						type: 0, 
																						house_override: 0)
##
# Crum / Get Covered Billing & Comission Strategies
                                  
@master_agency.billing_strategies.create!(title: 'Monthly', enabled: true, 
		                                      new_business: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      carrier: @crum, policy_type: PolicyType.find(4), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @master_agency 
		                                  			}
                                  				])
																						
@master_agency.commission_strategies.create!(title: 'Get Covered / Crum Commercial Commission',
																						carrier: Carrier.find(3), 
																						policy_type: PolicyType.find(4), 
																						amount: 15, 
																						type: 0, 
																						house_override: 0)
@master_agency.commission_strategies.create!(title: 'Get Covered / Crum Producer Commission',
																						carrier: Carrier.find(3), 
																						policy_type: PolicyType.find(4), 
																						amount: 3, 
																						type: 0, 
																						house_override: 0)

##
# Setting up data for demo sub residential agency
# this includes billing and commission strategies needed
# before an agency can sell policies

@sub_residential_agency = Agency.find(2)

##
# Adding relevant carriers to sub residential agency
# and setting up carrier agency authorizations 
# for each state

@sub_residential_agency.carriers << @qbe 
@sub_residential_agency.carriers << @qbe_specialty

@sub_residential_agency.carriers.each do |carrier|
	51.times do |state|
		
		@policy_type = nil
		@fee_amount = nil
		
		if carrier.id == 1
			@policy_type = PolicyType.find(1)
			@fee_amount = 1000
		elsif carrier.id == 2
			@policy_type = PolicyType.find(2)
		end
		
	  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
	  authorization = CarrierAgencyAuthorization.create(state: state, 
	  																									available: available, 
	  																									carrier_agency: CarrierAgency.where(carrier: carrier, agency: @sub_residential_agency).take, 
	  																									policy_type: @policy_type,
	  																									agency: @sub_residential_agency)
	  Fee.create(title: "Service Fee", 
	  					 type: :MISC, 
	  					 per_payment: true, 
	  					 amount: @fee_amount, 
	  					 amount_type: :PERCENTAGE, 
	  					 enabled: true, 
	  					 assignable: authorization, 
	  					 ownerable: @sub_residential_agency) unless @fee_amount.nil?
	end	
end

##
# QBE / Sub Residential Billing & Comission Strategies

@sub_residential_agency.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe, 
                                  				policy_type: PolicyType.find(1), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @sub_residential_agency 
		                                  			}
                                  				])
                                  
@sub_residential_agency.billing_strategies.create!(title: 'Bi-Annually', enabled: true, 
		                                      new_business: { payments: [50, 0, 0, 0, 0, 0, 59, 0, 0, 0, 0, 0], 
		                                                      payments_per_term: 2, remainder_added_to_deposit: true },
		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @sub_residential_agency 
		                                  			}
                                  				])
                                  
@sub_residential_agency.billing_strategies.create!(title: 'Quarterly', enabled: true, 
		                                      new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @sub_residential_agency 
		                                  			}
                                  				])
                                  
@sub_residential_agency.billing_strategies.create!(title: 'Monthly', enabled: true, 
		                                      new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @sub_residential_agency 
		                                  			}
                                  				])

@sub_residential_agency.commission_strategies.create!(title: "#{ @sub_residential_agency.title } / QBE Residential Commission", 
																						carrier: @qbe, 
																						policy_type: PolicyType.find(1), 
																						amount: 25, 
																						type: 0, 
																						commission_strategy_id: 2)	

##
# Setting up data for demo sub commercial agency
# this includes billing and commission strategies needed
# before an agency can sell policies

@sub_commercial_agency = Agency.find(3)

##
# Adding relevant carriers to sub commercial agency
# and setting up carrier agency authorizations 
# for each state

@sub_commercial_agency.carriers << @crum 

51.times do |state|
	
  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
  authorization = CarrierAgencyAuthorization.create(state: state, 
  																									available: available, 
  																									carrier_agency: CarrierAgency.where(carrier: @crum, agency: @sub_commercial_agency).take, 
  																									policy_type: PolicyType.find(4),
  																									agency: @sub_commercial_agency)
  Fee.create(title: "Service Fee", 
  					 type: :MISC, 
  					 per_payment: true, 
  					 amount: 800, 
  					 amount_type: :PERCENTAGE, 
  					 enabled: true, 
  					 assignable: authorization, 
  					 ownerable: @sub_commercial_agency)
end
	
##
# Crum / Sub Commercial Agency Billing & Comission Strategies
                                  
@sub_commercial_agency.billing_strategies.create!(title: 'Monthly', enabled: true, 
		                                      new_business: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      carrier: @crum, policy_type: PolicyType.find(4), 
                                  				fees_attributes: [
	                                  				{ 
		                                  				title: "Service Fee", 
		                                  				type: :MISC, 
		                                  				per_payment: true,
		                                  				amount: 1000, 
		                                  				enabled: true, 
		                                  				ownerable: @sub_residential_agency 
		                                  			}
                                  				])	
		                                      
@sub_commercial_agency.commission_strategies.create!(title: "#{ @sub_commercial_agency.title } / Crum Commercial Commission", 
																						carrier: @crum, 
																						policy_type: PolicyType.find(4), 
																						amount: 12, 
																						type: 0, 
																						commission_strategy_id: 8)