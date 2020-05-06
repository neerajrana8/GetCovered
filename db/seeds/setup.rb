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
  { title: "Commercial", designation: "BOP", enabled: true },
  { title: "Rent Guarantee", designation: "RENT-GUARANTEE", enabled: true }
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
  { title: "Small Business", category: "entity", enabled: true }, # ID: 6
  { title: "Residential Building", category: "property", enabled: true } # ID: 7
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
	},
  { 
	  title: "Pensio", 
	  integration_designation: 'pensio', 
	  syncable: false, 
	  rateable: false, 
	  quotable: true, 
	  bindable: true, 
	  verifiable: false, 
	  enabled: true 
	},
  {
    title: "Millennial Services Insurance",
    integration_designation: 'msi',
    syncable: false, # MOOSE WARNING: fix these
    rateable: false,
    quotable: false,
    bindable: false,
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
				    options: [true, false],
				    questionId: "1"
			    },
			    {
				    title: "Has any animal that you or your roommate(s) own ever bitten a person or someone else’s pet?",
				    value: 'false',
				    options: [true, false],
				    questionId: "2"
			    },
			    {
				    title: "Do you or your roommate(s) own snakes, exotic or wild animals?",
				    value: 'false',
				    options: [true, false],
				    questionId: "3"
			    },
			    {
				    title: "Is your dog(s) any of these breeds: Akita, Pit Bull (Staffordshire Bull Terrier, America Pit Bull Terrier, American Staffordshire Terrier, Bull Terrier), Chow, Rottweiler, Wolf Hybrid, Malamute or any mix of the above listed breeds?",
				    value: 'false',
				    options: [true, false],
				    questionId: "4"
			    },
			    {
				    title: "Have you had any liability claims, whether or not a payment was made, in the last 3 years?",
				    value: 'false',
				    options: [true, false],
				    questionId: "5"
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
            "other_business_description": nil,
          	"address": {
          		"street_number": nil,
          		"street_name": nil,
          		"street_two": nil,
          		"city": nil,
          		"state": nil,
          		"county": nil,
          		"zip_code": nil
          	}
          },
          "premise": [
          	{
          		"address": {
          			"street_number": nil,
          			"street_name": nil,
          			"street_two": nil,
          			"city": nil,
          			"state": nil,
          			"county": nil,
          			"zip_code": nil
          		},
          		"owned": false,	
          		"sqr_footage": 0,
              "annual_sales": 0,
              "building_limit": 0,
              "business_personal_property_limit": 0,
          		"full_time_employees": 0,
          		"part_time_employees": 0,
          		"major_class": nil,
          		"sub_class": nil,
          		"class_code": nil
          	}
          ],
          "policy_limits": {
          	"occurence_limit": 0,
          	"aggregate_limit": 0,
          	"building_limit": 0,
          	"business_personal_property": 0			
          }      																											
				},
				application_questions: [
					{
						"text": "Do you already have an insurance policy for your business, or have you applied for insurance through any agent other than \"Get Covered\"?",
						"value": false,
						"options": [true, false],
				    "questionId": "1"
					},
					{
						"text": "Do you currently sell or have you sold any fire arms, ammunition or weapons of any kind in the past?",
						"value": false,
						"options": [true, false],
				    "questionId": "2"
					},
					{
						"text": "Do you sell any products or perform any services for any military, law enforcement or other armed forces or services?",
						"value": false,
						"options": [true, false],
				    "questionId": "3"
					},
					{
						"text": "Do you own or operate any manned or unmanned aviation devices (aircraft, helicopters, drones etc)?",
						"value": false,
						"options": [true, false],
				    "questionId": "4"
					},
					{
						"text": "Do you directly import more than 5% of the cost of goods sold from a country or territory outside the U.S.?",
						"value": false,
						"options": [true, false],
				    "questionId": "5"
					},
					{
						"text": "Do you have any discontinued or ongoing operations involving the manufacturing, blending, repackaging or relabeling of components or products made by others?",
						"value": false,
						"options": [true, false],
				    "questionId": "6"
					},
					{
						"text": "Do you have any business premises that are open to the public?",
						"value": false,
						"options": [true, false],
						"questions": [
							{
								"text": "If YES, is your business open past 12:00 AM?",
								"value": false,
								"options": [true, false],
								"questionId": "7"
							}
						]
					},
					{
						"text": "Do you have a requirement  to post motor carrier financial responsibility filings to any Federal and or State Department of Transportation (DOT) or other agency?",
						"value": false,
						"options": [true, false],
				    "questionId": "8"
					},
					{
						"text": "Do you hire non-employee drivers to perform delivery of your products or services?",
						"value": false,
						"options": [true, false],
				    "questionId": "9"
					},
					{
						"text": "Do you have any employees use their own personal vehicles to make deliveries (food or otherwise) for 
			ten (10) days or more per month?",
						"value": false,
						"options": [true, false],
				    "questionId": "10"
					},
					{
						"text": "Please indicate the number of loss events to your business or claims made against you by others, whether covered by insurance or not, regardless of fault within the last three (3) years:",
						"value": false,
						"options": [true, false],
						"questions": [
							{
								"text": "Property loss events or claims:",
								"value": 0,
								"options": [0, 1, 2, 3],
								"questionId": "11A"
							},
							{
								"text": "General Liability events or claims:",
								"value": 0,
								"options": [0, 1, 2, 3],
								"questionId": "11B"
							},
							{
								"text": "Professional or Errors & Omissions Claims:",
								"value": 0,
								"options": [0, 1, 2, 3],
								"questionId": "11C"
							}				
						]
					}																									
				]	      
      )  
		      
		# Add Rental Guarantee to Pensio
		elsif carrier.id == 4
		
      policy_type = PolicyType.find(5)		
      carrier_policy_type = CarrierPolicyType.create!(
	      carrier: carrier,
	      policy_type: policy_type,
				application_required: true,
				application_fields: {
  				"monthly_rent": 0,
      		"guarantee_option": 3,
      		landlord: {
        	  "company": nil,
        	  "first_name": nil,
        	  "last_name": nil,
        	  "phone_number": nil,
        	  "email": nil	
      		},
  				employment: {
    				primary_applicant: {
      				"employment_type": nil,
      				"job_description": nil,
      				"monthly_income": nil,
      				"company_name": nil,
      				"company_phone_number": nil,
      				"address": {
              		"street_number": nil,
              		"street_name": nil,
              		"street_two": nil,
              		"city": nil,
              		"state": nil,
              		"county": nil,
              		"zip_code": nil,
              		"country": nil
      				}       				
    				},
    				secondary_applicant: {
      				"employment_type": nil,
      				"job_description": nil,
      				"monthly_income": nil,
      				"company_name": nil,
      				"company_phone_number": nil,
      				"address": {
              		"street_number": nil,
              		"street_name": nil,
              		"street_two": nil,
              		"city": nil,
              		"state": nil,
              		"county": nil,
              		"zip_code": nil,
              		"country": nil
      				}       				
    				}
  				}   				
				}
		  )    
      
    elsif carrier.id == 5
    
	    # Get Residential (HO4) Policy Type
      policy_type = PolicyType.find(1)

      # MSI Insurable Type for Residential Communities
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(1),
                                                            enabled: true, profile_traits: {
                                                              # community name, number of units, address fields
                                                              "professionally_managed_years": 6, # MUST BE PROF MAN
                                                              "property_manager_name": nil,
                                                              "community_sales_rep_id": nil, # ???
                                                              "construction_year": nil,
                                                              "gated": false
                                                            },
                                                            profile_data: {
                                                            })
      # MSI Insurable Type for Residential units
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(4), enabled: true)
      # Residential Unit Policy Type
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
				    options: [1, 2, 3, 4, 5, 6, 7, 8]
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
        carrier_policy_availability.fees.create(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier) unless carrier.id == 4
      end      
    else
      pp carrier_policy_type.errors
    end
  
  else
    pp carrier.errors
  end
end
