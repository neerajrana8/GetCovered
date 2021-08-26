

# delete IRCs and grab useful vars
carrier = MsiService.carrier
carrier_policy_type = CarrierPolicyType.where(carrier: carrier, policy_type_id: PolicyType::RESIDENTIAL_ID).take
InsurableRateConfiguration.where(carrier_policy_type: carrier_policy_type, configurable_type: 'InsurableGeographicalCategory', configurer: carrier).delete_all
InsurableGeographicalCategory.all.select{|igc| igc.insurable_rate_configurations.count == 0 }.each{|igc| igc.delete }
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
puts state
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
  event.response = result[:response]&.response
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
