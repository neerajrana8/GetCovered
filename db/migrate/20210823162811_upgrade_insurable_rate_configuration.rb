class UpgradeInsurableRateConfiguration < ActiveRecord::Migration[5.2]
  def up
    ::InsurableRateConfiguration.delete_all
    add_column :insurable_rate_configurations, :configuration, :jsonb, null: false, default: {}
    add_column :insurable_rate_configurations, :rates, :jsonb, null: false, default: {}
    add_reference :insurable_rate_configurations, :carrier_policy_type, null: false, index: { name: 'index_irc_on_cpt' }
    remove_column :insurable_rate_configurations, :coverage_options
    remove_column :insurable_rate_configurations, :rules
    remove_reference :insurable_rate_configurations, :carrier_insurable_type
    regen_msi_ircs({ carrier_policy_type: CarrierPolicyType.where(carrier_id: MsiService.carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID) })
  end
  
  def down
    ::InsurableRateConfiguration.delete_all
    add_reference :insurable_rate_configurations, :carrier_insurable_type, null: false, index: { name: 'index_irc_cit' }
    add_column :insurable_rate_configuration, :rules, :jsonb, null: false, default: {}
    add_column :insurable_rate_configuration, :coverage_options, :jsonb, null: false, default: []
    remove_reference :insurable_rate_configurations, :carrier_policy_type
    remove_column :insurable_rate_configurations, :rates
    remove_column :insurable_rate_configurations, :configuration
    regen_msi_ircs({ carrier_insurable_type: CarrierInsurableType.where(carrier_id: MsiService.carrier_id, insurable_type_id: 4 })
  end
  
  def regen_msi_ircs(specialz)
    msis = ::MsiService.new
    msis.extract_insurable_rate_configuration(nil,
      *{
        configurer: carrier,
        configurable: ::InsurableGeographicalCategory.get_for(state: nil),
        use_default_rules_for: 'USA'
      }.merge(specialz)
    ).save!
    ::Event.where(process: 'msi_get_product_definition', status: 'success', eventable_type: "InsurableGeographicalCategory").group_by{|evt| evt.eventable }.transform_values do |evts|
      resp = evts.max{|evt| evt.created_at }.response
      next (HTTParty::Parser.call(resp, :xml) rescue JSON.parse(resp.gsub("=>",":"))) # because legacy boiz were saving the hash, unfortunately
    end.each do |igc, data|
      defrules = igc.counties.blank? ? igc.state : ig.state == 'GA' ? 'GA_COUNTIES' : nil
      next if defrules.nil? # just in case
      msis.extract_insurable_rate_configuration(data,
        **{
          configurer: carrier,
          configurable: igc,
          use_default_rules_for: defrules
        }.merge(specialz)
      ).save!
    end
  end
  
end
