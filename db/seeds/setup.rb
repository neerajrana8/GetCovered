# Initial Seed Setup File
# file: db/seeds/setup.rb

require './db/seeds/functions'

##
# Setting up base Staff

@site_staff = [
  { email: 'admin@getcoveredllc.com', password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'super_admin', enabled: true, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines' }}
]

@site_staff.each do |staff|
  SeedFunctions.adduser(Staff, staff)
end

##
# Setting up base Policy Types

@policy_types = [
  { title: "Residential", designation: "HO4", enabled: true },
  { title: "Master Policy", designation: "MASTER", enabled: true },
  { title: "Master Policy Coverage", designation: "MASTER-COVERAGE", enabled: true },
  { title: "Commercial", designation: "BOP", enabled: true }
]

@policy_types.each do |pt|
  policy_type = PolicyType.create(pt)
end

##
# Setting up base Insurable Types

@insurable_types = [
  { title: "Residential Community", category: "property", enabled: true }, # ID: 1
  { title: "Mixed Use Community", category: "property", enabled: true }, # ID: 2
  { title: "Commercial Community", category: "property", enabled: true }, # ID: 3
  { title: "Residential Unit", category: "property", enabled: true }, # ID:4
  { title: "Commercial Unit", category: "property", enabled: true }, # ID: 5
  { title: "Small Business", category: "entity", enabled: true } # ID: 6
]

@insurable_types.each do |it|
  InsurableType.create(it)
end

##
# Lease Types

@lease_types = [
  { title: 'Residential', enabled: true }, # ID: 1
  { title: 'Commercial', enabled: true } # ID: 2
]

@lease_types.each do |lt|
  LeaseType.create(lt)
end

LeaseType.find(1).insurable_types << InsurableType.find(4)
LeaseType.find(1).policy_types << PolicyType.find(1)
LeaseType.find(1).policy_types << PolicyType.find(2)
LeaseType.find(2).insurable_types << InsurableType.find(5)
LeaseType.find(2).policy_types << PolicyType.find(4)

##
# Setting up base Carriers

@carriers = [
  { 
	  title: "Queensland Business Insurance", 
	  integration_designation: 'qbe',
	  syncable: false, 
	  rateable: true, 
	  quotable: true, 
	  bindable: true, 
	  verifiable: false, 
	  enabled: true 
	},
  { 
	  title: "Queensland Business Specialty Insurance",  
	  integration_designation: 'qbe_specialty',
	  syncable: false, 
	  rateable: true, 
	  quotable: true, 
	  bindable: true, 
	  verifiable: false, 
	  enabled: true 
	},
  { 
	  title: "Crum & Forester", 
	  integration_designation: 'crum', 
	  syncable: false, 
	  rateable: true, 
	  quotable: true, 
	  bindable: true, 
	  verifiable: false, 
	  enabled: true 
	}
]

@carriers.each do |c|
  carrier = Carrier.new(c)
  if carrier.save!
    
    carrier_policy_type = carrier.carrier_policy_types.new(application_required: carrier.id == 2 ? false : true)
    carrier.access_tokens.create!
    
    # Add Residential to Queensland Business Insurance
    if carrier.id == 1
	    
	    # Get Residential (HO4) Policy Type
      policy_type = PolicyType.find(1)
	    
# 	    # Create template for QBE Residential Policy Application
# 	    [
# 		    {
# 			  	title: "Number of Insured",
# 			  	answer_type: "NUMBER",
# 			  	default_answer: 1,
# 			    policy_type: policy_type,
# 			    section: 'fields',
# 			    enabled: true
# 		    },	    
# 		    {
# 			    title: "Do you operate a business in your rental apartment/home?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Has any animal that you or your roommate(s) own ever bitten a person or someone else’s pet?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Do you or your roommate(s) own snakes, exotic or wild animals?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Is your dog(s) any of these breeds: Akita, Pit Bull (Staffordshire Bull Terrier, America Pit Bull Terrier, American Staffordshire Terrier, Bull Terrier), Chow, Rottweiler, Wolf Hybrid, Malamute or any mix of the above listed breeds?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Have you had any liability claims, whether or not a payment was made, in the last 3 years?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    }
# 	    ].each do |policy_application_field|
# 		    carrier.policy_application_fields.create!(policy_application_field)
# 		  end  
      
      # Create QBE Insurable Type for Residential Communities with fields required for integration
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(1),
                                                            enabled: true, profile_traits: {
                                                              "pref_facility": "MDU",
                                                              "occupancy_type": "Other",
                                                              "construction_type": "F", # Options: F, MY, Superior
                                                              "protection_device_cd": "F", # Options: F, S, B, FB, SB
                                                              "alarm_credit": false,
                                                              "professionally_managed": false,
                                                              "professionally_managed_year": nil,
                                                              "construction_year": nil,
                                                              "bceg": nil,
                                                              "ppc": nil,
                                                              "gated": false,
                                                              "city_limit": true
                                                            },
                                                            profile_data: {
                                                              "county_resolved": false,
                                                              "county_last_resolved_on": nil,
                                                              "county_resolution": {
                                                                "selected": nil,
                                                                "results": [],
                                                                "matches": []
                                                              },
                                                              "property_info_resolved": false,
                                                              "property_info_last_resolved_on": nil,
                                                              "get_rates_resolved": false,
                                                              "get_rates_resolved_on": nil,
                                                              "rates_resolution": {
                                                                "1": false,
                                                                "2": false,
                                                                "3": false,
                                                                "4": false,
                                                                "5": false
                                                              },
                                                              "ho4_enabled": true
                                                            })
                                                            
      # Create QBE Insurable Type for Residential Units with fields required for integration (none in this example)                                  
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, 
      																											insurable_type: InsurableType.find(4), 
      																											enabled: true)
      
      carrier_policy_type = CarrierPolicyType.create!(
	      carrier: carrier,
	      policy_type: policy_type,
				application_required: true,
				application_fields: [
			    {
				  	title: "Number of Insured",
				  	answer_type: "INTEGER",
				  	default_answer: 1,
				  	value: 1,
				    options: [1, 2, 3, 4, 5]
			    }	      																											
				],
				application_questions: [
			    {
				    title: "Do you operate a business in your rental apartment/home?",
				    value: 'false',
				    options: [true, false]
			    },
			    {
				    title: "Has any animal that you or your roommate(s) own ever bitten a person or someone else’s pet?",
				    value: 'false',
				    options: [true, false]
			    },
			    {
				    title: "Do you or your roommate(s) own snakes, exotic or wild animals?",
				    value: 'false',
				    options: [true, false]
			    },
			    {
				    title: "Is your dog(s) any of these breeds: Akita, Pit Bull (Staffordshire Bull Terrier, America Pit Bull Terrier, American Staffordshire Terrier, Bull Terrier), Chow, Rottweiler, Wolf Hybrid, Malamute or any mix of the above listed breeds?",
				    value: 'false',
				    options: [true, false]
			    },
			    {
				    title: "Have you had any liability claims, whether or not a payment was made, in the last 3 years?",
				    value: 'false',
				    options: [true, false]
			    }	      																											
				]	      
      )             
                                          
    # Add Master to Queensland Business Specialty Insurance 
    elsif carrier.id == 2
      policy_type = PolicyType.find(2)
      policy_sub_type = PolicyType.find(3)
      
    # Add Commercial to Crum & Forester
    elsif carrier.id == 3
			crum_service = CrumService.new()
			crum_service.refresh_all_class_codes()
			
      policy_type = PolicyType.find(4)
			
# 	    # Create Template for Crum & Forester Commercial (B.O.P.) Questions
# 	    [
# 		    {
# 			    title: "Do you already have an insurance policy for your business, or have you applied for insurance through any agent other than \"Get Covered\"?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Currently sell or has it sold in the past any fire arms, ammunitions or weapons of any kind?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Sell any products or perform any services for any military, law enforcement or other armed forces or services?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Own or operate any manned or unmanned aviation devices (aircraft, helicopters, drones etc)?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Directly import more than 5% of the cost of goods sold from a country or territory outside the U.S,?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Have any discontinued or ongoing operations involving the manufacturing, blending, repackaging or relabeling of components or products made by others?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 		    },
# 		    {
# 			    title: "Have any business premises that are open to the public?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true,
# 			    policy_application_fields_attributes: [
# 						{
# 							title: 'If YES, is your business open past 12:00 AM?',
# 					    answer_type: "BOOLEAN",
# 					    default_answer: 'false',
# 							desired_answer: 'false',
# 					    policy_type: policy_type,
# 					    section: 'questions',
# 							carrier: carrier,
# 							enabled: true
# 						}
# 					]
# 				},
# 				{
# 					title: "Have a requirement  to post motor carrier financial responsibility filings to any Federal and or State Department of Transportation (DOT) or other agency?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 				},
# 				{
# 					title: "Hire non-employee drivers to perform delivery of your products or services?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 				},
# 				{
# 					title: "Have any employees use their own personal vehicles to make deliveries (food or otherwise) for 
# ten (10) days or or more per month?",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true
# 				},
# 				{
# 					title: "Please indicate the number of loss events to your business or claims made against you by others, whether covered by insurance or not, regardless of fault within the last three (3) years:",
# 			    answer_type: "BOOLEAN",
# 			    default_answer: 'false',
# 			  	desired_answer: 'false',
# 			    policy_type: policy_type,
# 			    section: 'questions',
# 			    enabled: true,
# 			    policy_application_fields_attributes: [
# 						{
# 							title: 'Property loss events or claims:',
# 					    answer_type: "NUMBER",
# 					    default_answer: '0',
# 							desired_answer: '0',
# 							answer_options: [0, 1, 2, 3],
# 					    policy_type: policy_type,
# 					    section: 'questions',
# 							carrier: carrier,
# 							enabled: true
# 						},
# 						{
# 							title: 'General Liability events or claims:',
# 					    answer_type: "NUMBER",
# 					    default_answer: '0',
# 							desired_answer: '0',
# 							answer_options: [0, 1, 2, 3],
# 					    policy_type: policy_type,
# 					    section: 'questions',
# 							carrier: carrier,
# 							enabled: true
# 						},
# 						{
# 							title: 'Professional or Errors & Omissions Claims:',
# 					    answer_type: "NUMBER",
# 					    default_answer: '0',
# 							desired_answer: '0',
# 							answer_options: [0, 1, 2, 3],
# 					    policy_type: policy_type,
# 					    section: 'questions',
# 							carrier: carrier,
# 							enabled: true
# 						}
# 					]
# 				}
# 	    ].each do |policy_application_field|
# 		    carrier.policy_application_fields.create!(policy_application_field)
# 		  end
      carrier_policy_type = CarrierPolicyType.create!(
	      carrier: carrier,
	      policy_type: policy_type,
				application_required: true,
				application_fields: {
					"business": {
						"number_of_insured": 1,
						"business_name": nil,
						"business_type": nil,
						"phone": nil,
						"website": nil,
						"contact_name": nil,
						"contact_title": nil,
						"contact_phone": nil,
						"contact_email": nil,
						"business_started": nil,
						"business_description": nil,
						"full_time_employees": nil,
						"part_time_employees": nil,
						"major_class": nil,
						"sub_class": nil,
						"class_code": nil,	
						"annual_sales": nil	
					},
					"premise": [
						{
							"address": {
								"street_number": "265",
								"street_name": "Canal St",
								"street_two": "#205",
								"city": "New York",
								"state": "NY",
								"county": "NEW YORK",
								"zip_code": "10013"
							},
							"owned": false,	
							"sqr_footage": nil,
						}
					],
					"policy_limits": {
						"liability": nil,
						"aggregate_limit": nil,
						"building_limit": nil,
						"business_personal_property": nil			
					}	      																											
				},
				application_questions: [
					{
						"text": "Do you already have an insurance policy for your business, or have you applied for insurance through any agent other than \"Get Covered\"?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Currently sell or has it sold in the past any fire arms, ammunitions or weapons of any kind?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Sell any products or perform any services for any military, law enforcement or other armed forces or services?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Own or operate any manned or unmanned aviation devices (aircraft, helicopters, drones etc)?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Directly import more than 5% of the cost of goods sold from a country or territory outside the U.S,?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Have any discontinued or ongoing operations involving the manufacturing, blending, repackaging or relabeling of components or products made by others?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Have any business premises that are open to the public?",
						"value": false,
						"options": [true, false],
						"questions": [
							{
								"text": "If YES, is your business open past 12:00 AM?",
								"value": false,
								"options": [true, false]
							}
						]
					},
					{
						"text": "Have a requirement  to post motor carrier financial responsibility filings to any Federal and or State Department of Transportation (DOT) or other agency?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Hire non-employee drivers to perform delivery of your products or services?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Have any employees use their own personal vehicles to make deliveries (food or otherwise) for 
			ten (10) days or or more per month?",
						"value": false,
						"options": [true, false]
					},
					{
						"text": "Please indicate the number of loss events to your business or claims made against you by others, whether covered by insurance or not, regardless of fault within the last three (3) years:",
						"value": false,
						"options": [true, false],
						"questions": [
							{
								"text": "Property loss events or claims:",
								"value": 0,
								"options": [0, 1, 2, 3]
							},
							{
								"text": "General Liability events or claims:",
								"value": 0,
								"options": [0, 1, 2, 3]
							},
							{
								"text": "Professional or Errors & Omissions Claims:",
								"value": 0,
								"options": [0, 1, 2, 3]
							}				
						]
					}																									
				]	      
      )  
		        
    end
    
    # Set policy type from if else block above
    carrier_policy_type.policy_type = policy_type
    
    if carrier_policy_type.save()
      51.times do |state|
        available = state == 0 || state == 11 ? false : true
        carrier_policy_availability = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: carrier_policy_type)
        carrier_policy_availability.fees.create(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier)
      end      
    else
      pp carrier_policy_type.errors
    end
  
  else
    pp carrier.errors
  end
end