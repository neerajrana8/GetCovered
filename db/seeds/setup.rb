# Initial Seed Setup File
# file: db/seeds/setup.rb

def adduser(user_type, chash)
  @user = user_type.new(chash)
  @user.invite! do |u|
    u.skip_invitation = true
  end
  token = Devise::VERSION >= "3.1.0" ? @user.instance_variable_get(:@raw_invitation_token) : @user.invitation_token
  user_type.accept_invitation!({invitation_token: token}.merge(chash))
  @user
end

##
# Setting up base Staff

@site_staff = [
  { email: 'admin@getcoveredllc.com', password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'super_admin', enabled: true, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines' }}
]

@site_staff.each do |staff|
  adduser(Staff, staff)
end

##
# Setting up base Policy Types

@policy_types = [
  { title: "Residential", designation: "HO4", enabled: true },
  { title: "Master Policy", designation: "MASTER", enabled: true },
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
LeaseType.find(2).policy_types << PolicyType.find(3)

##
# Setting up base Carriers

@carriers = [
  { title: "Queensland Business Insurance", syncable: false, rateable: true, quotable: true, bindable: true, verifiable: false, enabled: true },
  { title: "Queensland Business Specialty Insurance", syncable: false, rateable: true, quotable: true, bindable: true, verifiable: false, enabled: true },
  { title: "Crum & Forester", syncable: false, rateable: true, quotable: true, bindable: true, verifiable: false, enabled: true }
]

@carriers.each do |c|
  carrier = Carrier.new(c)
  if carrier.save!
    
    carrier_policy_type = carrier.carrier_policy_types.new(application_required: carrier.id == 2 ? false : true)

    # Add Residential to Queensland Business Insurance
    if carrier.id == 1
	    
	    # Create template for QBE Residential Policy Application
	    carrier_policy_type.application_fields = [
		    {
			  	title: "Number of Insured",
			  	type: "integer",
			  	default: 1,
			  	options: nil  
		    }
	    ]
	    
	    # Create Template for QBE Residential Policy Questions
	    carrier_policy_type.application_questions = [
		    {
			    title: "Do you operate a business in your rental apartment/home?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Has any animal that you or your roommate(s) own ever bitten a person or someone else’s pet?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Do you or your roommate(s) own snakes, exotic or wild animals?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Is your dog(s) any of these breeds: Akita, Pit Bull (Staffordshire Bull Terrier, America Pit Bull Terrier, American Staffordshire Terrier, Bull Terrier), Chow, Rottweiler, Wolf Hybrid, Malamute or any mix of the above listed breeds?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Have you had any liability claims, whether or not a payment was made, in the last 3 years?",
			    type: "boolean",
			    default: false
		    }
	    ]    
	    
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
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(4), enabled: true)
                                                            
    # Add Master to Queensland Business Specialty Insurance
    elsif carrier.id == 2
      policy_type = PolicyType.find(2)
      
    # Add Commercial to Crum & Forester
    elsif carrier.id == 3
      policy_type = PolicyType.find(3)
      
	    # Create Template for Crum & Forester Commercial (B.O.P.) Questions
	    carrier_policy_type.application_questions = [
		    {
			    title: "Do you already have an insurance policy for your business, or have you applied for insurance through any agent other than “Get Covered”?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Currently sell or has it sold in the past any fire arms, ammunitions or weapons of any kind?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Sell any products or perform any services for any military, law enforcement or other armed forces or services?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Own or operate any manned or unmanned aviation devices (aircraft, helicopters, drones etc)?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Directly import more than 5% of the cost of goods sold from a country or territory outside the U.S,?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Have any discontinued or ongoing operations involving the manufacturing, blending, repackaging or relabeling of components or products made by others?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Have any discontinued or ongoing operations involving the storage, application, transportation, recycling or disposal of any hazardous materials or substances?",
			    type: "boolean",
			    default: false
		    },
		    {
			    title: "Have any business premises that are open to the public?",
			    type: "boolean",
			    default: false
		    }
	    ]       
    end
    
    # Set policy type from if else block above
    carrier_policy_type.policy_type = policy_type
    
    if carrier_policy_type.save()
      51.times do |state|
        available = state == 0 || state == 11 ? false : true
        carrier_policy_availability = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: carrier_policy_type)
        carrier_policy_availability.fees.create(title: "Origination Fee", type: :ORIGINATION, amount: 25, enabled: true, ownerable: carrier)
      end      
    else
      pp carrier_policy_type.errors
    end
    
  end
end