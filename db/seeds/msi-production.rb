require './db/seeds/functions'
require 'faker'
require 'socket'

if !Carrier.where(id: 5).take.nil?
  puts "MSI CARRIER ALREADY EXISTS! NO NO NO!"
  exit
end

# setup.rb equivalent


carrier = Carrier.create({
  title: "Millennial Services Insurance",
  integration_designation: 'msi',
  syncable: false, 
  rateable: true, 
  quotable: true, 
  bindable: true, 
  verifiable: false, 
  enabled: true
})

puts "Initializing carrier #5..."

carrier_policy_type = carrier.carrier_policy_types.new(application_required: true)
carrier.access_tokens.create!


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

# Set up MSI InsurableRateConfigurations
msis = MsiService.new
# IRC for US
igc = ::InsurableGeographicalCategory.get_for(state: nil)
irc = msis.extract_insurable_rate_configuration(nil,
  configurer: carrier,
  configurable: igc,
  carrier_insurable_type: carrier_insurable_type,
  use_default_rules_for: 'USA'
)
irc.save!
# IRCs for the various states (and special counties)
::InsurableGeographicalCategory::US_STATE_CODES.each do |state, state_code|
  # make carrier IGC for this state
  igc = ::InsurableGeographicalCategory.get_for(state: state)
  # grab rates from MSI for this state
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
  # build IRC for this state
  irc = msis.extract_insurable_rate_configuration(result[:data],
    configurer: carrier,
    configurable: igc,
    carrier_insurable_type: carrier_insurable_type,
    use_default_rules_for: state
  )
  irc.save!
  # build county IRCs if needed
  if state.to_s == 'GA'
    igc = ::InsurableGeographicalCategory.get_for(state: state, counties: ['Bryan', 'Camden', 'Chatham', 'Glynn', 'Liberty', 'McIntosh'])
    irc = msis.extract_insurable_rate_configuration(nil,
      configurer: carrier,
      configurable: igc,
      carrier_insurable_type: carrier_insurable_type,
      use_default_rules_for: 'GA_COUNTIES'
    )
    irc.save!
  end
end


# Set policy type from if else block above
carrier_policy_type.policy_type = policy_type

if carrier_policy_type.save()
  51.times do |state|
    available = state == 0 || state == 11 ? false : true
    carrier_policy_availability = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: carrier_policy_type)
  end      
else
  pp carrier_policy_type.errors
end


# AGENCY stuff (agency.rb equivalent)

@msi = Carrier.find(5);          # Residential Carrier
@get_covered = Agency.where(title: "Get Covered").take
@get_covered.carriers << @msi

carrier = @msi
51.times do |state|
  @policy_type = PolicyType.find(1)
  available = state == 0 || state == 11 ? false : true # we don't do business in Alaska (0) and Hawaii (11)
  authorization = CarrierAgencyAuthorization.create(state: state, 
                                                    available: available, 
                                                    carrier_agency: CarrierAgency.where(carrier: carrier, agency: @get_covered).take, 
                                                    policy_type: @policy_type)
end


# MSI / Get Covered Billing & Commission Strategies

@get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @msi, 
                                          policy_type: PolicyType.find(1), carrier_code: "Annual",
                                          fees_attributes: [])
                                  
@get_covered.billing_strategies.create!(title: 'Bi-Annually', enabled: true,  carrier_code: "SemiAnnual",
                                          new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
                                                          payments_per_term: 2, remainder_added_to_deposit: true },
                                          carrier: @msi, policy_type: PolicyType.find(1), 
                                          fees_attributes: [])
                                  
@get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true,  carrier_code: "Quarterly",
                                          new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
                                                          payments_per_term: 4, remainder_added_to_deposit: true },
                                          carrier: @msi, policy_type: PolicyType.find(1), 
                                          fees_attributes: [])
@get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: "Monthly",
                                          new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
                                                          payments_per_term: 12, remainder_added_to_deposit: true },
                                          renewal: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
                                                          payments_per_term: 12, remainder_added_to_deposit: true },
                                          carrier: @msi, policy_type: PolicyType.find(1), 
                                          fees_attributes: [])

# MOOSE WARNING: these are just copies of the QBE commission strategies and likely need to be changed
@get_covered.commission_strategies.create!(title: 'Get Covered / MSI Residential Commission', 
                                            carrier: @msi, 
                                            policy_type: PolicyType.find(1), 
                                            amount: 30, 
                                            type: 0, 
                                            house_override: 0)
@get_covered.commission_strategies.create!(title: 'Get Covered / MSI Producer Commission', 
                                            carrier: @msi,
                                            policy_type: PolicyType.find(1), 
                                            amount: 5, 
                                            type: 0, 
                                            house_override: 0)

