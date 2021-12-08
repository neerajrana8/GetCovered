# Get Covered Agency Seed Setup File
# file: db/seeds/agency.rb

require './db/seeds/functions'
require 'faker'
require 'socket'

##
# Setting up carriers as individual instance variables
#
@qbe = Carrier.find(1)           # Residential Carrier
@qbe_specialty = Carrier.find(2) # Also qbe, but has to be a seperate entity for reasons i dont understand
@crum = Carrier.find(3)          # Commercial Carrier
@pensio = Carrier.find(4)
@msi = Carrier.find(5) unless ENV['skip_msi']          # Residential Carrier

##
# Set Up Get Covered
#
@get_covered = ::Agency.where(master_agency: true).take


site_staff = ENV['section'] == 'test' ? [] : [
  { email: "dylan@getcoveredllc.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @get_covered,
    profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
  { email: "brandon@getcoveredllc.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @get_covered,
    profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }},
  { email: "baha@getcoveredllc.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @get_covered,
    profile_attributes: { first_name: 'Baha', last_name: 'Sagadiev'}},
  { email: 'super_admin@getcovered.com', password: 'Test1234', password_confirmation: 'Test1234', role: 'super_admin', enabled: true,
    profile_attributes: { first_name: 'Super', last_name: 'Admin', job_title: 'Super Admin', birth_date: '01-01-0001'.to_date }},
  { email: 'agent@getcovered.com', password: 'Test1234', password_confirmation: 'Test1234', role: 'agent', enabled: true, organizable: @get_covered,
    profile_attributes: { first_name: 'Agent', last_name: 'Agent', job_title: 'Agent' }}
]

site_staff.each do |staff|
  SeedFunctions.adduser(Staff, staff)
end

[@qbe, @qbe_specialty, @crum, @pensio, ENV['skip_msi'] ? nil : @msi].compact.each do |carrier|
  ::CarrierAgency.create!(agency: @get_covered, carrier: carrier, carrier_agency_policy_types_attributes: carrier.carrier_policy_types.map do |cpt|
    {
      policy_type_id: cpt.policy_type_id # no need to specify commission percentage since for GC the CarrierPolicyType has the GC commission already & will be inherited
    }
  end)
end

CarrierAgency.where(agency_id: @get_covered.id, carrier_id: @qbe.id).take
             .update(external_carrier_id: "GETCVR")

service_fee = {
  title: "Service Fee",
  type: :MISC,
  amount_type: "PERCENTAGE",
  amortize: true,
  amount: 5,
  enabled: true,
  ownerable: @get_covered
}

# QBE / Get Covered Billing

@get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe,
                                          policy_type: PolicyType.find(1), carrier_code: "FL",
                                          new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                                          payments_per_term: 1, remainder_added_to_deposit: true },
                                          fees_attributes: [service_fee])

@get_covered.billing_strategies.create!(title: 'Bi-Annually', enabled: true,  carrier_code: "SA",
                                          new_business: { payments: [50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0],
                                                          payments_per_term: 2, remainder_added_to_deposit: true },
                                          carrier: @qbe, policy_type: PolicyType.find(1),
                                          fees_attributes: [service_fee])

@get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true,  carrier_code: "QT",
                                          new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0],
                                                          payments_per_term: 4, remainder_added_to_deposit: true },
                                          carrier: @qbe, policy_type: PolicyType.find(1),
                                          fees_attributes: [service_fee])

@get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: "QBE_MoRe",
                                          new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09],
                                                          payments_per_term: 12, remainder_added_to_deposit: true },
                                          renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33],
                                                          payments_per_term: 12, remainder_added_to_deposit: true },
                                          carrier: @qbe, policy_type: PolicyType.find(1),
                                          fees_attributes: [service_fee])

# Crum / Get Covered Billing

@get_covered.billing_strategies.create!(title: 'Monthly', enabled: true,  carrier_code: "M09",
                                        new_business: { payments: [25.03, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 0, 0],
                                                        payments_per_term: 12, remainder_added_to_deposit: true },
                                        renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33],
                                                        payments_per_term: 12, remainder_added_to_deposit: true },
                                        carrier: @crum, policy_type: PolicyType.find(4),
                                        fees_attributes: [service_fee])

@get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true,  carrier_code: "F",
                                        new_business: { payments: [40, 0, 0, 20, 0, 0, 20, 0, 0, 20, 0, 0],
                                                        payments_per_term: 4, remainder_added_to_deposit: true },
                                        carrier: @crum, policy_type: PolicyType.find(4),
                                        fees_attributes: [service_fee])

@get_covered.billing_strategies.create!(title: 'Annually', enabled: true,  carrier_code: "A",
                                        new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                                        payments_per_term: 1, remainder_added_to_deposit: true },
                                        carrier: @crum, policy_type: PolicyType.find(4),
                                        fees_attributes: [service_fee])



@get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: nil,
                                          new_business: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33],
                                                          payments_per_term: 12, remainder_added_to_deposit: true },
                                          carrier: @pensio, policy_type: PolicyType.find(5),
                                          fees_attributes: [service_fee])

# MSI / Get Covered Billing
unless ENV['skip_msi']
  @get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @msi,
                                            policy_type: PolicyType.find(1), carrier_code: "Annual",
                                            new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                                            payments_per_term: 1, remainder_added_to_deposit: true },
                                            fees_attributes: [service_fee])

  @get_covered.billing_strategies.create!(title: 'Bi-Annually', enabled: true,  carrier_code: "SemiAnnual",
                                            new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0],
                                                            payments_per_term: 2, remainder_added_to_deposit: true },
                                            carrier: @msi, policy_type: PolicyType.find(1),
                                            fees_attributes: [service_fee])

  @get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true,  carrier_code: "Quarterly",
                                            new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0],
                                                            payments_per_term: 4, remainder_added_to_deposit: true },
                                            carrier: @msi, policy_type: PolicyType.find(1),
                                            fees_attributes: [service_fee])
  # MOOSE WARNING: docs say 20% down payment and 10 monthly payments... wut sense dis make?
  @get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: "Monthly",
                                            new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09],
                                                            payments_per_term: 12, remainder_added_to_deposit: true },
                                            renewal: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33],
                                                            payments_per_term: 12, remainder_added_to_deposit: true },
                                            carrier: @msi, policy_type: PolicyType.find(1),
                                            fees_attributes: [service_fee])
end

unless ENV['section'] == 'test'

##
# Set Up Cambridge
#

@cambridge_agencies = [
  {
    title: "Cambridge QBE",
    enabled: true,
    whitelabel: true,
    tos_accepted: true,
    tos_accepted_at: Time.current,
    tos_acceptance_ip: nil,
    verified: false,
    stripe_id: nil,
    master_agency: false,
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
    ]
  },
  {
    title: "Cambridge GC",
    enabled: true,
    whitelabel: true,
    tos_accepted: true,
    tos_accepted_at: Time.current,
    tos_acceptance_ip: nil,
    verified: false,
    stripe_id: nil,
    master_agency: false,
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
    ]
  }
]

@cambridge_agencies.each do |ca|
  cambridge_agency = Agency.new(ca)
  if cambridge_agency.save
    cambridge_agency = cambridge_agency.reload
    site_staff = [
      { email: "dylan@#{ cambridge_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: cambridge_agency,
        profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
      { email: "brandon@#{ cambridge_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: cambridge_agency,
        profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }},
      { email: "josh@#{ cambridge_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: cambridge_agency,
        profile_attributes: { first_name: 'Josh', last_name: 'Brinsfield'}}
    ]

    site_staff.each do |staff|
      SeedFunctions.adduser(Staff, staff)
    end

    qbe_agency_id = cambridge_agency.title == "Cambridge QBE" ? "CAMBQBE" : "CAMBGC"
    [@qbe, @qbe_specialty].each do |carrier|
      ::CarrierAgency.create!(carrier: carrier, agency: cambridge_agency, external_carrier_id: carrier == @qbe ? qbe_agency_id : nil, carrier_agency_policy_types_attributes: carrier.carrier_policy_types.map do |cpt|
        {
          policy_type_id: cpt.policy_type_id,
          commission_strategy_attributes: { percentage: 25 }
        }
      end)
    end
  else
    pp cambridge_agency.errors
  end
end

##
# Set Up GC Agencies
#

@get_covered_agencies = [
  {
    agency: @get_covered,
    title: "Get Covered 002",
    enabled: true,
    whitelabel: true,
    tos_accepted: true,
    tos_accepted_at: Time.current,
    tos_acceptance_ip: nil,
    verified: false,
    stripe_id: nil,
    master_agency: false,
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
  {
    agency: @get_covered,
    title: "Get Covered 011",
    enabled: true,
    whitelabel: true,
    tos_accepted: true,
    tos_accepted_at: Time.current,
    tos_acceptance_ip: nil,
    verified: false,
    stripe_id: nil,
    master_agency: false,
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

  }
]

@get_covered_agencies.each do |gca|
  gc_qbesub_agency = Agency.new(gca)
  if gc_qbesub_agency.save

    gc_qbesub_agency = gc_qbesub_agency.reload

    site_staff = [
      { email: "dylan@#{ gc_qbesub_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: gc_qbesub_agency,
        profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
      { email: "brandon@#{ gc_qbesub_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: gc_qbesub_agency,
        profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }},
      { email: "josh@#{ gc_qbesub_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: gc_qbesub_agency,
        profile_attributes: { first_name: 'Josh', last_name: 'Brinsfield'}}
    ]

    site_staff.each do |staff|
      SeedFunctions.adduser(Staff, staff)
    end
    
    qbe_agency_id = gc_qbesub_agency.title == "Get Covered 002" ? "Get002" : "Get011"
    [@qbe, @qbe_specialty].each do |carrier|
      ::CarrierAgency.create!(carrier: carrier, agency: gc_qbesub_agency, external_carrier_id: carrier == @qbe ? qbe_agency_id : nil, carrier_agency_policy_types_attributes: carrier.carrier_policy_types.map do |cpt|
        {
          policy_type_id: cpt.policy_type_id,
          commission_strategy_attributes: { percentage: 25 }
        }
      end)
    end
  else
    pp gc_qbesub_agency.errors
  end
end

end # end "unless ENV['section'] == 'test'"
