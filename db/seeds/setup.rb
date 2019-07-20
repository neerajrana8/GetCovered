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
    
    # Add Residential to Queensland Business Insurance
    if carrier.id == 1
      policy_type = PolicyType.find(1)
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(1),
                                                            enabled: true, profile_traits: {
                                                              "pref_facility": "MDU",
                                                              "occupancy_type": "Other",
                                                              "construction_type": nil,
                                                              "protection_device_cd": "F",
                                                              "alarm_credit": false,
                                                              "professionally_managed": false,
                                                              "professionally_managed_year": nil,
                                                              "construction_year": nil,
                                                              "bceg": nil,
                                                              "ppc": nil,
                                                              "gated": false
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
                                                              }
                                                            })
      carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(4), enabled: true)
                                                            
    # Add Master to Queensland Business Specialty Insurance
    elsif carrier.id == 2
      policy_type = PolicyType.find(2)
      
    # Add Commercial to Crum & Forester
    elsif carrier.id == 3
      policy_type = PolicyType.find(3)
    end
    
    carrier_policy_type = carrier.carrier_policy_types.new(policy_type: policy_type, application_required: carrier.id == 2 ? false : true)
    
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