class AddCarrierSelectionsToAgency < ActiveRecord::Migration[5.2]
  def change
    add_column :agencies, :carrier_preferences, :jsonb, null: false, default: { 'by_policy_type' => {} }
    
    Agency.reset_column_information
    states = Address::US_STATE_CODES.keys.map{|s| s.to_s }
    agencies = Agency.all.map{|a| [a.id, a] }.to_h
    CarrierAgencyPolicyType.references(:carrier_agencies).includes(:carrier_agency).each do |capt|
      agency = agencies[capt.carrier_agency.agency_id]
      next if agency.nil?
      agency.carrier_preferences['by_policy_type'][capt.policy_type_id.to_s] ||= []
      if capt.policy_type_id == ::PolicyType::RESIDENTIAL_ID && capt.carrier_agency.carrier_id == 5 # residential defaults to MSI wherever possible
        agency.carrier_preferences['by_policy_type'][capt.policy_type_id.to_s].unshift(capt.carrier_agency.carrier_id)
      else
        agency.carrier_preferences['by_policy_type'][capt.policy_type_id.to_s].push(capt.carrier_agency.carrier_id)
      end
      agency.carrier_preferences['by_policy_type'][capt.policy_type_id.to_s].uniq!
    end
    agencies.each do |aid, a|
      a.carrier_preferences['by_policy_type'].transform_values!{|v| states.map{|s| [s, { 'carrier_ids' => v }] }.to_h }
      a.save!
    end
    
  end
end
