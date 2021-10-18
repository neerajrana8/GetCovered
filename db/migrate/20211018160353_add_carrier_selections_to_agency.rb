class AddCarrierSelectionsToAgency < ActiveRecord::Migration[5.2]
  def change
    add_column :agencies, :carrier_selections, :jsonb, null: false, default: {}
    
    states = Address::US_STATE_CODES.keys.map{|s| s.to_s }
    agencies = Agency.all.map{|a| [a.id, a] }.to_h
    CarrierAgencyPolicyType.references(:carrier_agencies).includes(:carrier_agency).each do |capt|
      agency = agencies[capt.carrier_agency.agency_id]
      next if agency.nil?
      agency.carrier_selections['by_policy_type'] ||= {}
      agency.carrier_selections['by_policy_type'][capt.policy_type_id.to_s][capt.state] ||= []
      agency.carrier_selections['by_policy_type'][capt.policy_type_id.to_s][capt.state]['carrier_ids'] ||= []
      if capt.policy_type_id == ::PolicyType::RESIDENTIAL_ID && capt.carrier_agency.carrier_id == 5 # residential defaults to MSI wherever possible
        agency.carrier_selections['by_policy_type'][capt.policy_type_id.to_s][capt.state]['carrier_ids'].unshift(capt.carrier_agency.carrier_id)
      else
        agency.carrier_selections['by_policy_type'][capt.policy_type_id.to_s][capt.state]['carrier_ids'].push(capt.carrier_agency.carrier_id)
      end
    end
    agencies.each{|a| a.save! }
    
  end
end
