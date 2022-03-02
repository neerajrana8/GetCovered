class UpgradeInsurableRateConfiguration < ActiveRecord::Migration[5.2]
  def up
    irc_count = ::InsurableRateConfiguration.all.count
    ::InsurableRateConfiguration.delete_all
    add_column :insurable_rate_configurations, :configuration, :jsonb, null: false, default: {}
    add_column :insurable_rate_configurations, :rates, :jsonb, null: false, default: {}
    add_reference :insurable_rate_configurations, :carrier_policy_type, null: false, index: { name: 'index_irc_on_cpt' }
    remove_column :insurable_rate_configurations, :coverage_options
    remove_column :insurable_rate_configurations, :rules
    remove_reference :insurable_rate_configurations, :carrier_insurable_type
    InsurableRateConfiguration.reset_column_information
    regen_msi_ircs({ carrier_policy_type: CarrierPolicyType.where(carrier_id: MsiService.carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take }) unless irc_count == 0
  end
  
  def down
    irc_count = ::InsurableRateConfiguration.all.count
    ::InsurableRateConfiguration.delete_all
    add_reference :insurable_rate_configurations, :carrier_insurable_type, null: false, index: { name: 'index_irc_cit' }
    add_column :insurable_rate_configuration, :rules, :jsonb, null: false, default: {}
    add_column :insurable_rate_configuration, :coverage_options, :jsonb, null: false, default: []
    remove_reference :insurable_rate_configurations, :carrier_policy_type
    remove_column :insurable_rate_configurations, :rates
    remove_column :insurable_rate_configurations, :configuration
    # currently the code won't work with carrier_insurable_type; you would have to revert the branch first. so we shouldn't run this.
    #regen_msi_ircs({ carrier_insurable_type: CarrierInsurableType.where(carrier_id: MsiService.carrier_id, insurable_type_id: 4 }) unless irc_count == 0
  end
  
  def regen_msi_ircs(specialz)
    carrier = ::MsiService.carrier
    msis = ::MsiService.new
    # usa
    msis.extract_insurable_rate_configuration(nil,
      **{
        configurer: carrier,
        configurable: ::InsurableGeographicalCategory.get_for(state: nil),
        use_default_rules_for: 'USA'
      }.merge(specialz)
    ).save!
    # ga counties
    msis.extract_insurable_rate_configuration(nil,
      **{
        configurer: carrier,
        configurable: ::InsurableGeographicalCategory.get_for(state: 'GA', counties: ['Bryan', 'Camden', 'Chatham', 'Glynn', 'Liberty', 'McIntosh']),
        use_default_rules_for: 'GA_COUNTIES'
      }.merge(specialz)
    ).save!
    # get per-state igc data
    by_igc = ::Event.where(process: 'msi_get_product_definition', status: 'success', eventable_type: "InsurableGeographicalCategory").group_by{|evt| evt.eventable }.select{|k,v| !k.nil? }.transform_values do |evts|
      resp = evts.max{|evt| evt.created_at }.response
      next (HTTParty::Parser.call(resp, :xml) rescue JSON.parse(resp.gsub("=>",":"))) # because legacy boiz were saving the hash, unfortunately
    end
    # get data from MSI for any missing states, as opposed to leaving them missing
    #puts "USSC: #{::InsurableGeographicalCategory::US_STATE_CODES.keys}"
    #puts "BIGC: #{by_igc.map{|k,v| k.state.to_sym }}"
    #puts "MINS: #{(::InsurableGeographicalCategory::US_STATE_CODES.keys - by_igc.map{|k,v| k.state.to_sym })}"
    #(::InsurableGeographicalCategory::US_STATE_CODES.keys - by_igc.map{|k,v| k.state.to_sym }).each do |state|
    #  dat_igc = ::InsurableGeographicalCategory.get_for(state: state)
    #  by_igc[dat_igc] = get_data_from_msi(msis, dat_igc)
    #end
    # create per-state ircs
    by_igc.each do |igc, data|
      next if igc.nil? || !igc.counties.blank? # just in case
      msis.extract_insurable_rate_configuration(data,
        **{
          configurer: carrier,
          configurable: igc,
          use_default_rules_for: igc.state
        }.merge(specialz)
      ).save!
    end
  end
  
  def get_data_from_msi(msis, igc)
    # grab rates from MSI for this state
    result = msis.build_request(:get_product_definition,
      effective_date: Time.current.to_date + 2.days,
      state: igc.state
    )
    unless result
      pp msis.errors
      puts "!!!!!MSI GET RATES FAILURE (#{igc.state})!!!!!"
      raise Exception
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
      puts "!!!!!MSI GET RATES FAILURE (#{igc.state})!!!!!"
      raise Exception
    end
    return result[:response]&.parsed_response
  end
  
end
