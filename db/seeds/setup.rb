# Initial Seed Setup File
# file: db/seeds/setup.rb

require './db/seeds/functions'
require './db/seeds/faked-msi-responses'

##
# Setting up base Staff

@site_staff = [
  { email: 'admin@getcoveredllc.com', password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'super_admin', enabled: true, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines' }}
]

@site_staff.each do |staff|
  SeedFunctions.adduser(Staff, staff)
end

##
# Setting up GetCovered (we need a master agency for various things to work right)

@get_covered = Agency.create!(
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
)

##
# Setting up base Policy Types

@policy_types = [
  { id: 1, title: "Residential", designation: "HO4", enabled: true },
  { id: 2, title: "Master Policy", designation: "MASTER", enabled: true, master: true },
  { id: 3, title: "Master Policy Coverage", designation: "MASTER-COVERAGE", enabled: true, master_coverage: true, master_policy_id: 2 },
  { id: 4, title: "Commercial", designation: "BOP", enabled: true },
  { id: 5, title: "Rent Guarantee", designation: "RENT-GUARANTEE", enabled: true },
  { id: 6, title: "Security Deposit Replacement", designation: "SECURITY-DEPOSIT", enabled: true },
  { id: 7, title: "Master Security Deposit Replacement", designation: "MASTER-SECURITY-DEPOSIT", enabled: true, master: true },
  { id: 8, title: "Master Security Deposit Replacement Coverage", designation: "MASTER-SECURITY-DEPOSIT-COVERAGE", enabled: true, master_coverage: true, master_policy_id: 7 }
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
	  syncable: false, 
	  rateable: true, 
	  quotable: true, 
	  bindable: true, 
	  verifiable: false, 
    enabled: true
  }
]

@carriers.select!{|c| c[:integration_designation] != 'msi' } if ENV['skip_msi']

@carriers.each do |c|
  carrier = Carrier.new(c)
  if carrier.save!
    puts "Initializing carrier ##{carrier.id} (#{carrier.title})..."
    
    ::CommissionStrategy.create!(
      title: "#{carrier.title} Parent Commission",
      percentage: 100,
      recipient: carrier
    )
    
    carrier.access_tokens.create!
    carrier_policy_type = nil

    # Add Residential to Queensland Business Insurance
    if carrier.id == 1
	    
	    # Get Residential (HO4) Policy Type
      policy_type = PolicyType.find(1)
      
      # Create QBE Insurable Type for Residential Communities with fields required for integration
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(1),
                                                            enabled: true, profile_traits: {
                                                              "pref_facility": "FIC",
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
        premium_proration_refunds_allowed: true,
        max_days_for_full_refund: 30,
        commission_strategy_attributes: { recipient: @get_covered, percentage: 30 },
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
            title: "Do You Conduct Any Business In Your Rental Apartment/Home?",
            value: 'false',
            options: [true, false],
            questionId: 1
          },
          {
						title: "Have You Or Anyone In The House Filed A Liability Claim, Including Any Animal Related Claims?",
						value: 'false',
						options: [true, false],
						questionId: 2
          }
				]
      )
      51.times do |state|
        available = state == 0 || state == 11 ? false : true
        carrier_policy_availability = CarrierPolicyTypeAvailability.create!(state: state, available: available, carrier_policy_type: carrier_policy_type)
        carrier_policy_availability.fees.create!(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier) unless carrier.id == 4
      end
      # create QBE master policy
      [::PolicyType.find(2), ::PolicyType.find(3)].each do |master_policy_type|
        carrier_policy_type = CarrierPolicyType.create!(
          carrier: carrier,
          policy_type: master_policy_type,
          application_required: false,
          commission_strategy_attributes: { recipient: @get_covered, percentage: 30 },
          application_fields: [],
          application_questions: []
        )
        51.times do |state|
          available = state == 0 || state == 11 ? false : true
          carrier_policy_availability = CarrierPolicyTypeAvailability.create!(state: state, available: available, carrier_policy_type: carrier_policy_type)
          carrier_policy_availability.fees.create!(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier) unless carrier.id == 4
        end
      end
    # Add Master to Queensland Business Specialty Insurance
    elsif carrier.id == 2
      [::PolicyType.find(2), ::PolicyType.find(3)].each do |policy_type|
        carrier_policy_type = CarrierPolicyType.create!(
          carrier: carrier,
          policy_type: policy_type,
          application_required: false,
          commission_strategy_attributes: { recipient: @get_covered, percentage: 30 },
          application_fields: [],
          application_questions: []
        )
        51.times do |state|
          available = state == 0 || state == 11 ? false : true
          carrier_policy_availability = CarrierPolicyTypeAvailability.create!(state: state, available: available, carrier_policy_type: carrier_policy_type)
          carrier_policy_availability.fees.create!(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier) unless carrier.id == 4
        end
      end
    # Add Commercial to Crum & Forester
    elsif carrier.id == 3
			crum_service = CrumService.new()
			# crum_service.refresh_all_class_codes()
			
      policy_type = PolicyType.find(4)

      carrier_policy_type = CarrierPolicyType.create!(
	      carrier: carrier,
	      policy_type: policy_type,
				application_required: true,
        premium_proration_refunds_allowed: true,
        max_days_for_full_refund: 30,
        commission_strategy_attributes: { recipient: @get_covered, percentage: 30 },
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

      51.times do |state|
        available = state == 0 || state == 11 ? false : true
        carrier_policy_availability = CarrierPolicyTypeAvailability.create!(state: state, available: available, carrier_policy_type: carrier_policy_type)
        carrier_policy_availability.fees.create!(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier) unless carrier.id == 4
      end
		      
		# Add Rental Guarantee to Pensio
		elsif carrier.id == 4
		
      policy_type = PolicyType.find(5)		
      carrier_policy_type = CarrierPolicyType.create!(
	      carrier: carrier,
	      policy_type: policy_type,
				application_required: true,
        premium_proration_refunds_allowed: false,
        max_days_for_full_refund: 30,
        commission_strategy_attributes: { recipient: @get_covered, percentage: 30 },
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
      51.times do |state|
        available = state == 0 || state == 11 ? false : true
        carrier_policy_availability = CarrierPolicyTypeAvailability.create!(state: state, available: available, carrier_policy_type: carrier_policy_type)
        carrier_policy_availability.fees.create!(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier) unless carrier.id == 4
      end
      
    elsif carrier.id == 5
    
	    # Get Residential (HO4) Policy Type
      policy_type = PolicyType.find(1)

      # MSI Insurable Type for Residential Communities
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(1),
                                                            enabled: true, profile_traits: {
                                                              "professionally_managed": true,
                                                              "professionally_managed_year": nil,
                                                              "construction_year": nil,
                                                              "gated": false
                                                            },
                                                            profile_data: {
                                                              "address_corrected": false,
                                                              "address_correction_data": {},
                                                              "address_correction_failed": false,
                                                              "address_correction_errors": nil,
                                                              "registered_with_msi": false,
                                                              "registered_with_msi_on": nil,
                                                              "msi_external_id": nil
                                                            })
      # MSI Insurable Type for Residential units
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(4), enabled: true)
      # Residential Unit Policy Type
      carrier_policy_type = CarrierPolicyType.create!(
	      carrier: carrier,
	      policy_type: policy_type,
				application_required: true,
        premium_proration_refunds_allowed: true,
        max_days_for_full_refund: 30,
        commission_strategy_attributes: { recipient: @get_covered, percentage: 30 },
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
      51.times do |state|
        available = state == 0 || state == 11 ? false : true
        carrier_policy_availability = CarrierPolicyTypeAvailability.create!(state: state, available: available, carrier_policy_type: carrier_policy_type)
        carrier_policy_availability.fees.create!(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: carrier) unless carrier.id == 4
      end
      
      # Set up MSI InsurableRateConfigurations
      msis = MsiService.new
      # IRC for US
      igc = ::InsurableGeographicalCategory.get_for(state: nil)
      irc = msis.extract_insurable_rate_configuration(nil,
        configurer: carrier,
        configurable: igc,
        carrier_policy_type: carrier_policy_type,
        use_default_rules_for: 'USA'
      )
      irc.save!
      # IRCs for the various states (and special counties)
      ::InsurableGeographicalCategory::US_STATE_CODES.each do |state, state_code|
        # make carrier IGC for this state
        igc = ::InsurableGeographicalCategory.get_for(state: state)
        # grab rates from MSI for this state
        result = nil
        unless ENV['real_msi_calls'] || Rails.env == 'production'
          result = { data: FakedMsiResponses::RESPONSES[state.to_s] }
        else
          result = msis.build_request(:get_product_definition,
            effective_date: Time.current.to_date + 2.days,
            state: state
          )
          unless result
            pp msis.errors
            puts "!!!!!MSI GET RATES FAILURE (#{state})!!!!!"
            exit
          end
          event = ::Event.new(
            eventable: igc,
            verb: 'post',
            format: 'xml',
            interface: 'REST',
            endpoint: msis.endpoint_for(:get_product_definition),
            process: 'msi_get_product_definition'
          )
          event.request = msis.compiled_rxml
          event.save!
          event.started = Time.now
          result = msis.call
          event.completed = Time.now     
          event.response = result[:data]
          event.status = result[:error] ? 'error' : 'success'
          event.save!
          if result[:error]
            pp result[:response]&.parsed_response
            puts ""
            puts "!!!!!MSI GET RATES FAILURE (#{state})!!!!!"
            exit
          end
        end
        # build IRC for this state
        irc = msis.extract_insurable_rate_configuration(result[:data],
          configurer: carrier,
          configurable: igc,
          carrier_policy_type: carrier_policy_type,
          use_default_rules_for: state
        )
        irc.save!
        # build county IRCs if needed
        if state.to_s == 'GA'
          igc = ::InsurableGeographicalCategory.get_for(state: state, counties: ['Bryan', 'Camden', 'Chatham', 'Glynn', 'Liberty', 'McIntosh']) 
          irc = msis.extract_insurable_rate_configuration(nil,
            configurer: carrier,
            configurable: igc,
            carrier_policy_type: carrier_policy_type,
            use_default_rules_for: 'GA_COUNTIES'
          )
          irc.save!
        end
      end
		  
    end
    
  
  else
    pp carrier.errors
  end
end
