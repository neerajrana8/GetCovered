# Initial Seed Setup File
# file: db/seeds/setup.rb

require './db/seeds/functions'
require 'faker'
require 'socket'

AccessToken.first.update enabled: true

InsurableType.create(title: "Residential Building", 
                     category: "property", 
                     enabled: true) unless InsurableType.exists?(title: "Residential Building")

@occupant_shield = Account.new(title: "Occupant Shield", enabled: true, whitelabel: true, 
															 tos_accepted: true, tos_accepted_at: Time.current, 
															 tos_acceptance_ip: Socket.ip_address_list.select{ |intf| intf.ipv4_loopback? }, 
															 verified: true, stripe_id: nil, agency: Agency.where(title: "Cambridge GC").take,
														   addresses_attributes: [
													  		{
													  			street_number: "100",
													  			street_name: "Pearl Street",
													  			street_two: "14th Floor",
													  			city: "Hartford",
													  			state: "CT",
													  			county: "HARTFORD COUNTY",
													  			zip_code: "06103",
													  			primary: true
													  		}																	   
														   ])

if @occupant_shield.save
	SeedFunctions.adduser(Staff, { 
		email: "mel@getcoveredllc.com", 
		password: 'TestingPassword1234', 
		password_confirmation: 'TestingPassword1234', 
		role: 'staff', 
		enabled: true, 
		organizable: @occupant_shield, 
  	profile_attributes: { 
	  	first_name: 'Melissa', 
	  	last_name: 'Christman', 
	  	job_title: 'Operations Manager', 
	  	birth_date: '04-01-1989'.to_date 
	  }	
	})	
else
	pp @occupant_shield.errors
end
    																 
@cambridge_community = Insurable.new(title: "Residences at Executive Park",
                                     insurable_type: InsurableType.find(1), 
																		 enabled: true, category: 'property',
																		 account: @occupant_shield,
																		 addresses_attributes: [
																		   {
																		 	   street_number: "1",
																		 	   street_name: "Vanderbilt Dr.",
																		 	   city: "Merrimack",
																		 	   state: "NH",
																		 	   zip_code: "03054"
																		   }
																		 ])

if @cambridge_community.save
	
	@cambridge_community.create_carrier_profile(1)
	
	@profile = @cambridge_community.carrier_profile(1)
	@profile.traits["protection_device_cd"] = "S"
	@profile.traits["construction_type"] = "R"
	@profile.traits["construction_year"] = 2019
	@profile.traits["professionally_managed"] = true
	@profile.traits["professionally_managed_year"] = 2019
	@profile.save
	
	Assignment.create!(staff: @occupant_shield.owner, assignable: @cambridge_community)

	@cambridge_community.get_qbe_zip_code()
	@cambridge_community.get_qbe_property_info()
	
  @five_vanderbilt = Insurable.new(title: "Five Vanderbilt", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "5",
																 	     street_name: "Vanderbilt Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
	if @five_vanderbilt.save
		# 5 Vanderbilt Dr.
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 201, 
		 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 301, 302, 
		 303, 304, 305, 306, 307, 308, 309, 310, 311, 401, 402, 403, 
		 404, 405, 406, 407, 408, 409, 410, 411].each do |unit|
			 
			@unit = @five_vanderbilt.insurables.new(title: "#{ unit } at #{ @five_vanderbilt.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
				  	 
	  end			
	else
		pp @five_vanderbilt.errors
	end	
	
  @three_vanderbilt = Insurable.new(title: "Three Vanderbilt", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "3",
																 	     street_name: "Vanderbilt Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
  
  if @three_vanderbilt.save
		# 3 Vanderbilt Drive
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 
		 113, 114, 115, 116, 201, 202, 203, 204, 205, 206, 207, 208, 
		 209, 210, 211, 212, 213, 214, 215, 216, 301, 302, 303, 304, 
		 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 
		 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 
		 413, 414, 415, 416].each do |unit|
			 
			@unit = @three_vanderbilt.insurables.new(title: "#{ unit } at #{ @three_vanderbilt.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
			 
		end
	else
		pp @three_vanderbilt.errors
	end
	
  @four_executive = Insurable.new(title: "Four Executive", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "4",
																 	     street_name: "Executive Park Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
  
  if @four_executive.save
		# 4 Executive Park Drive
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 
		 113, 114, 115, 116, 201, 202, 203, 204, 205, 206, 207, 208, 
		 209, 210, 211, 212, 213, 214, 215, 216, 301, 302, 303, 304, 
		 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 
		 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 
		 413, 414, 415, 416].each do |unit|
			 
			@unit = @four_executive.insurables.new(title: "#{ unit } at #{ @four_executive.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
			 
		end
	else
		pp @four_executive.errors
	end
	
  @two_pan_american = Insurable.new(title: "Two Pan American", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "2",
																 	     street_name: "Pan American Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
  
  if @two_pan_american.save
		# 2 Pan American Drive
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 201, 
		 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 301, 302, 
		 303, 304, 305, 306, 307, 308, 309, 310, 311, 401, 402, 403, 
		 404, 405, 406, 407, 408, 409, 410, 411].each do |unit|
			 
			@unit = @two_pan_american.insurables.new(title: "#{ unit } at #{ @two_pan_american.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
			 
		end
	else
		pp @two_pan_american.errors
	end
	
  @one_pan_american = Insurable.new(title: "One Pan American", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "1",
																 	     street_name: "Pan American Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
  
  if @one_pan_american.save
		# 1 Pan American Drive
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 
		 113, 114, 115, 116, 201, 202, 203, 204, 205, 206, 207, 208, 
		 209, 210, 211, 212, 213, 214, 215, 216, 301, 302, 303, 304, 
		 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 
		 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 
		 413, 414, 415, 416].each do |unit|
			 
			@unit = @one_pan_american.insurables.new(title: "#{ unit } at #{ @one_pan_american.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
			 
		end
	else
		pp @one_pan_american.errors
	end
 
	@cambridge_community.reset_qbe_rates(true, true)
  @cambridge_community.insurable_rates.optional.update_all mandatory: true
  
  enabled_cov_c_rates_ids = []
  enabled_cov_c_rates_ids.concat @cambridge_community.insurable_rates.coverage_c.where("(coverage_limits ->> 'coverage_c')::integer = ?", 1000000).map(&:id)
  enabled_cov_c_rates_ids.concat @cambridge_community.insurable_rates.coverage_c.where("(coverage_limits ->> 'coverage_c')::integer = ?", 1500000).map(&:id)
  enabled_cov_c_rates_ids.concat @cambridge_community.insurable_rates.coverage_c.where("(coverage_limits ->> 'coverage_c')::integer = ?", 2000000).map(&:id)
  
  enabled_liability_rates_ids = @cambridge_community.insurable_rates.liability.where("(coverage_limits ->> 'liability')::integer >= ?", 10000000).map(&:id)
  
  @cambridge_community.insurable_rates.coverage_c.where.not(id: enabled_cov_c_rates_ids).update_all enabled: false
  @cambridge_community.insurable_rates.liability.where.not(id: enabled_liability_rates_ids).update_all enabled: false
  
  profile = @cambridge_community.carrier_profile(1)
  message = profile.data.to_json
  
  ActionMailer::Base.mail(from: 'info@getcoveredinsurance.com', to: ['dylan@getcoveredllc.com', 'brandon@getcoveredllc.com'], subject: "Cambridge Seeding Complete", body: message).deliver
  
else
	pp @cambridge_community.errors
end

# ##
# # Setting up base Staff
# 
# @site_staff = [
#   { email: 'admin@getcoveredllc.com', password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'super_admin', enabled: true, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines' }}
# ]
# 
# @site_staff.each do |staff|
#   SeedFunctions.adduser(Staff, staff)
# end
# 
# ##
# # Setting up base Policy Types
# 
# @policy_types = [
#   { title: "Residential", designation: "HO4", enabled: true },
#   { title: "Master Policy", designation: "MASTER", enabled: true },
#   { title: "Master Policy Coverage", designation: "MASTER-COVERAGE", enabled: true },
#   { title: "Commercial", designation: "BOP", enabled: true }
# ]
# 
# @policy_types.each do |pt|
#   policy_type = PolicyType.create(pt)
# end
# 
# ##
# # Setting up base Insurable Types
# 
# @insurable_types = [
#   { title: "Residential Community", category: "property", enabled: true }, # ID: 1
#   { title: "Mixed Use Community", category: "property", enabled: true }, # ID: 2
#   { title: "Commercial Community", category: "property", enabled: true }, # ID: 3
#   { title: "Residential Unit", category: "property", enabled: true }, # ID:4
#   { title: "Commercial Unit", category: "property", enabled: true }, # ID: 5
#   { title: "Small Business", category: "entity", enabled: true } # ID: 6
# ]
# 
# @insurable_types.each do |it|
#   InsurableType.create(it)
# end
# 
# ##
# # Lease Types
# 
# @lease_types = [
#   { title: 'Residential', enabled: true }, # ID: 1
#   { title: 'Commercial', enabled: true } # ID: 2
# ]
# 
# @lease_types.each do |lt|
#   LeaseType.create(lt)
# end
# 
# LeaseType.find(1).insurable_types << InsurableType.find(4)
# LeaseType.find(1).policy_types << PolicyType.find(1)
# LeaseType.find(1).policy_types << PolicyType.find(2)
# LeaseType.find(2).insurable_types << InsurableType.find(5)
# LeaseType.find(2).policy_types << PolicyType.find(4)
# 
# ##
# # Setting up base Carriers
# 
# @carriers = [
#   { 
# 	  title: "Queensland Business Insurance", 
# 	  integration_designation: 'qbe',
# 	  syncable: false, 
# 	  rateable: true, 
# 	  quotable: true, 
# 	  bindable: true, 
# 	  verifiable: false, 
# 	  enabled: true 
# 	},
#   { 
# 	  title: "Queensland Business Specialty Insurance",  
# 	  integration_designation: 'qbe_specialty',
# 	  syncable: false, 
# 	  rateable: true, 
# 	  quotable: true, 
# 	  bindable: true, 
# 	  verifiable: false, 
# 	  enabled: true 
# 	},
#   { 
# 	  title: "Crum & Forester", 
# 	  integration_designation: 'crum', 
# 	  syncable: false, 
# 	  rateable: true, 
# 	  quotable: true, 
# 	  bindable: true, 
# 	  verifiable: false, 
# 	  enabled: true 
# 	}
# ]
# 
# @carriers.each do |c|
#   carrier = Carrier.new(c)
#   if carrier.save!
#     
#     carrier_policy_type = carrier.carrier_policy_types.new(application_required: carrier.id == 2 ? false : true)
#     carrier.access_tokens.create!
#     
#     # Add Residential to Queensland Business Insurance
#     if carrier.id == 1
# 
# 	    access_token = AccessToken.first
# 	    message = "key: #{ access_token.key }\nsecret: #{ access_token.secret }"
# 	    
# 	    ActionMailer::Base.mail(from: 'info@getcoveredinsurance.com', to: ['dylan@getcoveredllc.com', 'brandon@getcoveredllc.com', 'Shalini.Koshy@us.qbe.com'], subject: "Production Access Token", body: message).deliver
# 	    
# 	    # Get Residential (HO4) Policy Type
#       policy_type = PolicyType.find(1) 
#       
#       # Create QBE Insurable Type for Residential Communities with fields required for integration
#       carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(1),
#                                                             enabled: true, profile_traits: {
#                                                               "pref_facility": "MDU",
#                                                               "occupancy_type": "Other",
#                                                               "construction_type": "F", # Options: F, MY, Superior
#                                                               "protection_device_cd": "F", # Options: F, S, B, FB, SB
#                                                               "alarm_credit": false,
#                                                               "professionally_managed": false,
#                                                               "professionally_managed_year": nil,
#                                                               "construction_year": nil,
#                                                               "bceg": nil,
#                                                               "ppc": nil,
#                                                               "gated": false,
#                                                               "city_limit": true
#                                                             },
#                                                             profile_data: {
#                                                               "county_resolved": false,
#                                                               "county_last_resolved_on": nil,
#                                                               "county_resolution": {
#                                                                 "selected": nil,
#                                                                 "results": [],
#                                                                 "matches": []
#                                                               },
#                                                               "property_info_resolved": false,
#                                                               "property_info_last_resolved_on": nil,
#                                                               "get_rates_resolved": false,
#                                                               "get_rates_resolved_on": nil,
#                                                               "rates_resolution": {
#                                                                 "1": false,
#                                                                 "2": false,
#                                                                 "3": false,
#                                                                 "4": false,
#                                                                 "5": false
#                                                               },
#                                                               "ho4_enabled": true
#                                                             })
#                                                             
#       # Create QBE Insurable Type for Residential Units with fields required for integration (none in this example)                                  
#       carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, 
#       																											insurable_type: InsurableType.find(4), 
#       																											enabled: true)
#       
#       carrier_policy_type = CarrierPolicyType.create!(
# 	      carrier: carrier,
# 	      policy_type: policy_type,
# 				application_required: true,
# 				application_fields: [
# 			    {
# 				  	title: "Number of Insured",
# 				  	answer_type: "INTEGER",
# 				  	default_answer: 1,
# 				  	value: 1,
# 				    options: [1, 2, 3, 4, 5]
# 			    }	      																											
# 				],
# 				application_questions: [
# 			    {
# 				    title: "Do you operate a business in your rental apartment/home?",
# 				    value: 'false',
# 				    options: [true, false]
# 			    },
# 			    {
# 				    title: "Has any animal that you or your roommate(s) own ever bitten a person or someone else’s pet?",
# 				    value: 'false',
# 				    options: [true, false]
# 			    },
# 			    {
# 				    title: "Do you or your roommate(s) own snakes, exotic or wild animals?",
# 				    value: 'false',
# 				    options: [true, false]
# 			    },
# 			    {
# 				    title: "Is your dog(s) any of these breeds: Akita, Pit Bull (Staffordshire Bull Terrier, America Pit Bull Terrier, American Staffordshire Terrier, Bull Terrier), Chow, Rottweiler, Wolf Hybrid, Malamute or any mix of the above listed breeds?",
# 				    value: 'false',
# 				    options: [true, false]
# 			    },
# 			    {
# 				    title: "Have you had any liability claims, whether or not a payment was made, in the last 3 years?",
# 				    value: 'false',
# 				    options: [true, false]
# 			    }	      																											
# 				]	      
#       )             
#                                           
#     # Add Master to Queensland Business Specialty Insurance 
#     elsif carrier.id == 2
#       policy_type = PolicyType.find(2)
#       policy_sub_type = PolicyType.find(3)
#       
#     # Add Commercial to Crum & Forester
#     elsif carrier.id == 3
# 			crum_service = CrumService.new()
# 			crum_service.refresh_all_class_codes()
# 			
#       policy_type = PolicyType.find(4)
#       
#       carrier_policy_type = CarrierPolicyType.create!(
# 	      carrier: carrier,
# 	      policy_type: policy_type,
# 				application_required: true,
# 				application_fields: {
#           "business": {
#           	"number_of_insured": 1,
#           	"business_name": nil,
#           	"business_type": nil,
#           	"phone": nil,
#           	"website": nil,
#           	"contact_name": nil,
#           	"contact_title": nil,
#           	"contact_phone": nil,
#           	"contact_email": nil,
#           	"business_started": nil,
#           	"business_description": nil,
#             "other_business_description": nil,
#           	"address": {
#           		"street_number": nil,
#           		"street_name": nil,
#           		"street_two": nil,
#           		"city": nil,
#           		"state": nil,
#           		"county": nil,
#           		"zip_code": nil
#           	}
#           },
#           "premise": [
#           	{
#           		"address": {
#           			"street_number": nil,
#           			"street_name": nil,
#           			"street_two": nil,
#           			"city": nil,
#           			"state": nil,
#           			"county": nil,
#           			"zip_code": nil
#           		},
#           		"owned": false,	
#           		"sqr_footage": 0,
#               "annual_sales": 0,
#               "building_limit": 0,
#               "business_personal_property_limit": 0,
#           		"full_time_employees": 0,
#           		"part_time_employees": 0,
#           		"major_class": nil,
#           		"sub_class": nil,
#           		"class_code": nil
#           	}
#           ],
#           "policy_limits": {
#           	"occurence_limit": 0,
#           	"aggregate_limit": 0,
#           	"building_limit": 0,
#           	"business_personal_property": 0			
#           }	     																											
# 				},
# 				application_questions: [
# 					{
# 						"text": "Do you already have an insurance policy for your business, or have you applied for insurance through any agent other than \"Get Covered\"?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Currently sell or has it sold in the past any fire arms, ammunitions or weapons of any kind?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Sell any products or perform any services for any military, law enforcement or other armed forces or services?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Own or operate any manned or unmanned aviation devices (aircraft, helicopters, drones etc)?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Directly import more than 5% of the cost of goods sold from a country or territory outside the U.S,?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Have any discontinued or ongoing operations involving the manufacturing, blending, repackaging or relabeling of components or products made by others?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Have any business premises that are open to the public?",
# 						"value": false,
# 						"options": [true, false],
# 						"questions": [
# 							{
# 								"text": "If YES, is your business open past 12:00 AM?",
# 								"value": false,
# 								"options": [true, false]
# 							}
# 						]
# 					},
# 					{
# 						"text": "Have a requirement  to post motor carrier financial responsibility filings to any Federal and or State Department of Transportation (DOT) or other agency?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Hire non-employee drivers to perform delivery of your products or services?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Have any employees use their own personal vehicles to make deliveries (food or otherwise) for 
# 			ten (10) days or or more per month?",
# 						"value": false,
# 						"options": [true, false]
# 					},
# 					{
# 						"text": "Please indicate the number of loss events to your business or claims made against you by others, whether covered by insurance or not, regardless of fault within the last three (3) years:",
# 						"value": false,
# 						"options": [true, false],
# 						"questions": [
# 							{
# 								"text": "Property loss events or claims:",
# 								"value": 0,
# 								"options": [0, 1, 2, 3]
# 							},
# 							{
# 								"text": "General Liability events or claims:",
# 								"value": 0,
# 								"options": [0, 1, 2, 3]
# 							},
# 							{
# 								"text": "Professional or Errors & Omissions Claims:",
# 								"value": 0,
# 								"options": [0, 1, 2, 3]
# 							}				
# 						]
# 					}																									
# 				]	      
#       )  
# 		        
#     end
#     
#     # Set policy type from if else block above
#     carrier_policy_type.policy_type = policy_type
#     
#     if carrier_policy_type.save()
#       51.times do |state|
#         available = state == 0 || state == 11 ? false : true
#         carrier_policy_availability = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: carrier_policy_type)
#         carrier_policy_availability.fees.create(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier)
#       end      
#     else
#       pp carrier_policy_type.errors
#     end
#   
#   else
#     pp carrier.errors
#   end
# end
# 
# # Get Covered Agency Seed Setup File
# # file: db/seeds/agency.rb
# 
# ##
# # Setting up carriers as individual instance variables
# #
# @qbe = Carrier.find(1)           # Residential Carrier
# @qbe_specialty = Carrier.find(2) # Also qbe, but has to be a seperate entity for reasons i dont understand
# @crum = Carrier.find(3)          # Commercial Carrier
# 
# ##
# # Set Up Get Covered
# #
# 
# @get_covered = Agency.new(
# 	title: "Get Covered", 
# 	enabled: true, 
# 	whitelabel: true, 
# 	tos_accepted: true, 
# 	tos_accepted_at: Time.current, 
# 	tos_acceptance_ip: nil, 
# 	verified: false, 
# 	stripe_id: nil, 
# 	master_agency: true,
# 	addresses_attributes: [
# 		{
# 			street_number: "265",
# 			street_name: "Canal St",
# 			street_two: "#205",
# 			city: "New York",
# 			state: "NY",
# 			county: "NEW YORK",
# 			zip_code: "10013",
# 			primary: true
# 		}
# 	]	  
# )
# 
# if @get_covered.save
#   site_staff = [
#     { email: "dylan@getcoveredllc.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @get_covered, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
#     { email: "brandon@getcoveredllc.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @get_covered, profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }}
# 	]
#   
#   site_staff.each do |staff|
#     SeedFunctions.adduser(Staff, staff)
#   end
# 
#   @get_covered.carriers << @qbe 
#   @get_covered.carriers << @qbe_specialty
#   @get_covered.carriers << @crum  
#   
#   CarrierAgency.where(agency_id: @get_covered.id, carrier_id: @qbe.id).take
#                .update(external_carrier_id: "GETCVR")
# 
#   @get_covered.carriers.each do |carrier|
#   	51.times do |state|
#   		
#   		@policy_type = nil
#   		@fee_amount = nil
#   		
#   		if carrier.id == 1
#   			@policy_type = PolicyType.find(1)
#   			@fee_amount = 2500
#   		elsif carrier.id == 2
#   			@policy_type = PolicyType.find(2)
#   		elsif carrier.id == 3
#   			@policy_type = PolicyType.find(4)
#   			@fee_amount = 2500
#   		end
#   		
#   	  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
#   	  authorization = CarrierAgencyAuthorization.create(state: state, 
#   	  																									available: available, 
#   	  																									carrier_agency: CarrierAgency.where(carrier: carrier, agency: @get_covered).take, 
#   	  																									policy_type: @policy_type,
#   	  																									agency: @get_covered)
#   	  Fee.create(title: "Service Fee", 
#   	  					 type: :MISC, 
#   	  					 per_payment: false,
#   	  					 amortize: false, 
#   	  					 amount: @fee_amount, 
#   	  					 amount_type: :FLAT, 
#   	  					 enabled: true, 
#   	  					 assignable: authorization, 
#   	  					 ownerable: @get_covered) unless @fee_amount.nil?
#   	end	
#   end
# 
#   @get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe, 
#                                     				policy_type: PolicyType.find(1), 
#                                     				fees_attributes: [
#   	                                  				{ 
#   		                                  				title: "Service Fee", 
#   		                                  				type: :MISC, 
#   		                                  				per_payment: true,
#   		                                  				amount: 1000, 
#   		                                  				enabled: true, 
#   		                                  				ownerable: @get_covered 
#   		                                  			}
#                                     				])
#                                     
#   @get_covered.billing_strategies.create!(title: 'Bi-Annually', enabled: true, 
#   		                                      new_business: { payments: [50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
#   		                                                      payments_per_term: 2, remainder_added_to_deposit: true },
#   		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
#                                     				fees_attributes: [
#   	                                  				{ 
#   		                                  				title: "Service Fee", 
#   		                                  				type: :MISC, 
#   		                                  				per_payment: true,
#   		                                  				amount: 1000, 
#   		                                  				enabled: true, 
#   		                                  				ownerable: @get_covered 
#   		                                  			}
#                                     				])
#                                     
#   @get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true, 
#   		                                      new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
#   		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
#   		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
#                                     				fees_attributes: [
#   	                                  				{ 
#   		                                  				title: "Service Fee", 
#   		                                  				type: :MISC, 
#   		                                  				per_payment: true,
#   		                                  				amount: 1000, 
#   		                                  				enabled: true, 
#   		                                  				ownerable: @get_covered 
#   		                                  			}
#                                     				])
#                                     
#   @get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, 
#   		                                      new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
#   		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
#   		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
#   		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
#   		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
#                                     				fees_attributes: [
#   	                                  				{ 
#   		                                  				title: "Service Fee", 
#   		                                  				type: :MISC, 
#   		                                  				per_payment: true,
#   		                                  				amount: 1000, 
#   		                                  				enabled: true, 
#   		                                  				ownerable: @get_covered 
#   		                                  			}
#                                     				])
#   
#   @get_covered.commission_strategies.create!(title: 'Get Covered / QBE Residential Commission', 
#   																						carrier: Carrier.find(1), 
#   																						policy_type: PolicyType.find(1), 
#   																						amount: 30, 
#   																						type: 0, 
#   																						house_override: 0)
#   @get_covered.commission_strategies.create!(title: 'Get Covered / QBE Producer Commission', 
#   																						carrier: Carrier.find(1), 
#   																						policy_type: PolicyType.find(1), 
#   																						amount: 5, 
#   																						type: 0, 
#   																						house_override: 0)
#   ##
#   # Crum / Get Covered Billing & Comission Strategies
#                                     
#   @get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, 
# 		                                      new_business: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
# 		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
# 		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
# 		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
# 		                                      carrier: @crum, policy_type: PolicyType.find(4), 
#                                   				fees_attributes: [
# 	                                  				{ 
# 		                                  				title: "Service Fee", 
# 		                                  				type: :MISC, 
# 		                                  				per_payment: true,
# 		                                  				amount: 1000, 
# 		                                  				enabled: true, 
# 		                                  				ownerable: @get_covered 
# 		                                  			}
#                                   				])
#   																						
#   @get_covered.commission_strategies.create!(title: 'Get Covered / Crum Commercial Commission',
# 																						 carrier: Carrier.find(3), 
# 																						 policy_type: PolicyType.find(4), 
# 																						 amount: 15, 
# 																						 type: 0, 
# 																						 house_override: 0)
#   @get_covered.commission_strategies.create!(title: 'Get Covered / Crum Producer Commission',
# 																						 carrier: Carrier.find(3), 
# 																						 policy_type: PolicyType.find(4), 
# 																						 amount: 3, 
# 																						 type: 0, 
# 																						 house_override: 0)
#  
# else
#   logger.debug @get_covered.errors
# end
# 
# @cambridge = Agency.new(
# 	title: "Cambridge", 
# 	enabled: true, 
# 	whitelabel: true, 
# 	tos_accepted: true, 
# 	tos_accepted_at: Time.current, 
# 	tos_acceptance_ip: nil, 
# 	verified: false, 
# 	stripe_id: nil, 
# 	master_agency: false,
# 	addresses_attributes: [
# 		{
# 			street_number: "100",
# 			street_name: "Pearl Street",
# 			street_two: "14th Floor",
# 			city: "Hartford",
# 			state: "CT",
# 			county: "HARTFORD COUNTY",
# 			zip_code: "06103",
# 			primary: true
# 		}
# 	]	
# )
# 
# if @cambridge.save    
#   site_staff = [
#     { email: "jen@occupantshield.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @cambridge, profile_attributes: { first_name: 'Jen', last_name: 'Pruchnicki', job_title: 'Operations Manager', birth_date: '04-01-1989'.to_date }}
#   ]
#   
#   site_staff.each do |staff|
#     SeedFunctions.adduser(Staff, staff)
#   end	
#   
#   @cambridge.carriers << @qbe 
#   @cambridge.carriers << @qbe_specialty
#   
#   qbe_agency_id = "CAMBGC"
#   
#   CarrierAgency.where(agency_id: @cambridge.id, carrier_id: @qbe.id).take
#                .update(external_carrier_id: qbe_agency_id)  
# 
#   @cambridge.carriers.each do |carrier|
#   	51.times do |state|
#   		
#   		@policy_type = nil
#   		@fee_amount = nil
#   		
#   		if carrier.id == 1
#   			@policy_type = PolicyType.find(1)
#   			@fee_amount = 4500
#   		elsif carrier.id == 2
#   			@policy_type = PolicyType.find(2)
#   		end
#   		
#   	  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
#   	  authorization = CarrierAgencyAuthorization.create(state: state, 
#   	  																									available: available, 
#   	  																									carrier_agency: CarrierAgency.where(carrier: carrier, agency: @cambridge).take, 
#   	  																									policy_type: @policy_type,
#   	  																									agency: @cambridge)
#   	  Fee.create(title: "Service Fee", 
#   	  					 type: :MISC, 
#   	  					 per_payment: false,
#   	  					 amortize: false, 
#   	  					 amount: @fee_amount, 
#   	  					 amount_type: :FLAT, 
#   	  					 enabled: true, 
#   	  					 assignable: authorization, 
#   	  					 ownerable: @cambridge) unless @fee_amount.nil?
#   	end	
#   end 
#   
#   @cambridge.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe, 
#                                     				  policy_type: PolicyType.find(1))
#                                     
#   @cambridge.billing_strategies.create!(title: 'Bi-Annually', enabled: true, 
#     		                                      new_business: { payments: [50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
#     		                                                      payments_per_term: 2, remainder_added_to_deposit: true },
#     		                                      carrier: @qbe, policy_type: PolicyType.find(1))
#                                     
#   @cambridge.billing_strategies.create!(title: 'Quarterly', enabled: true, 
#     		                                      new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
#     		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
#     		                                      carrier: @qbe, policy_type: PolicyType.find(1))
#                                     
#   @cambridge.billing_strategies.create!(title: 'Monthly', enabled: true, 
#     		                                      new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
#     		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
#     		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
#     		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
#     		                                      carrier: @qbe, policy_type: PolicyType.find(1))    
# 
#   @cambridge.commission_strategies.create!(title: "#{ @cambridge.title } / QBE Residential Commission", 
#     																						 carrier: @qbe, 
#     																						 policy_type: PolicyType.find(1), 
#     																						 amount: 25, 
#     																						 type: 0, 
#     																						 commission_strategy_id: 2)	
# 
# else
# 	logger.debug @cambridge.errors
# end
# 
# @cambridge_qbe = Agency.new(
# 	title: "Cambridge", 
# 	enabled: true, 
# 	whitelabel: true, 
# 	tos_accepted: true, 
# 	tos_accepted_at: Time.current, 
# 	tos_acceptance_ip: nil, 
# 	verified: false, 
# 	stripe_id: nil, 
# 	master_agency: false,
# 	addresses_attributes: [
# 		{
# 			street_number: "100",
# 			street_name: "Pearl Street",
# 			street_two: "14th Floor",
# 			city: "Hartford",
# 			state: "CT",
# 			county: "HARTFORD COUNTY",
# 			zip_code: "06103",
# 			primary: true
# 		}
# 	]	
# )
# 
# if @cambridge_qbe.save    
#   site_staff = [
#     { email: "erickawood@yahoo.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @cambridge_qbe, profile_attributes: { first_name: 'Ericka', last_name: 'Wood', job_title: 'Operations Manager', birth_date: '04-01-1989'.to_date }}
#   ]
#   
#   site_staff.each do |staff|
#     SeedFunctions.adduser(Staff, staff)
#   end	
#   
#   @cambridge_qbe.carriers << @qbe 
#   @cambridge_qbe.carriers << @qbe_specialty
#   
#   qbe_agency_id = "CAMBQBE"
#   
#   CarrierAgency.where(agency_id: @cambridge_qbe.id, carrier_id: @qbe.id).take
#                .update(external_carrier_id: qbe_agency_id)  
# 
#   @cambridge_qbe.carriers.each do |carrier|
#   	51.times do |state|
#   		
#   		@policy_type = nil
#   		@fee_amount = nil
#   		
#   		if carrier.id == 1
#   			@policy_type = PolicyType.find(1)
#   			@fee_amount = 4500
#   		elsif carrier.id == 2
#   			@policy_type = PolicyType.find(2)
#   		end
#   		
#   	  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
#   	  authorization = CarrierAgencyAuthorization.create(state: state, 
#   	  																									available: available, 
#   	  																									carrier_agency: CarrierAgency.where(carrier: carrier, agency: @cambridge_qbe).take, 
#   	  																									policy_type: @policy_type,
#   	  																									agency: @cambridge_qbe)
#   	  Fee.create(title: "Service Fee", 
#   	  					 type: :MISC, 
#   	  					 per_payment: false,
#   	  					 amortize: false, 
#   	  					 amount: @fee_amount, 
#   	  					 amount_type: :FLAT, 
#   	  					 enabled: true, 
#   	  					 assignable: authorization, 
#   	  					 ownerable: @cambridge_qbe) unless @fee_amount.nil?
#   	end	
#   end 
#   
#   @cambridge_qbe.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe, 
#                                     				  policy_type: PolicyType.find(1))
#                                     
#   @cambridge_qbe.billing_strategies.create!(title: 'Bi-Annually', enabled: true, 
#     		                                      new_business: { payments: [50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
#     		                                                      payments_per_term: 2, remainder_added_to_deposit: true },
#     		                                      carrier: @qbe, policy_type: PolicyType.find(1))
#                                     
#   @cambridge_qbe.billing_strategies.create!(title: 'Quarterly', enabled: true, 
#     		                                      new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
#     		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
#     		                                      carrier: @qbe, policy_type: PolicyType.find(1))
#                                     
#   @cambridge_qbe.billing_strategies.create!(title: 'Monthly', enabled: true, 
#     		                                      new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
#     		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
#     		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
#     		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
#     		                                      carrier: @qbe, policy_type: PolicyType.find(1))    
# 
#   @cambridge_qbe.commission_strategies.create!(title: "#{ @cambridge_qbe.title } / QBE Residential Commission", 
#     																						 carrier: @qbe, 
#     																						 policy_type: PolicyType.find(1), 
#     																						 amount: 25, 
#     																						 type: 0, 
#     																						 commission_strategy_id: 2)	
# 
# else
# 	logger.debug @cambridge_qbe.errors
# end