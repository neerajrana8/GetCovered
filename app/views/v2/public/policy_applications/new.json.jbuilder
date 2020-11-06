json.extract! @application, :reference, :external_reference,
  :effective_date, :expiration_date, :status, :status_updated_on, 
  :fields, :questions, :carrier_id, :policy_type_id, :agency_id,
  :account_id, :billing_strategy_id, :coverage_selections


json.policy_rates_attributes []
json.policy_insurables_attributes (@preferred ? [] : @application.policy_insurables.map do |pi|
  addr = pi.insurable.primary_address
  {
    primary: pi.primary || (@application.policy_insurables.count == 1),
    insurable_id: pi.insurable_id,
    insurable_attributes: {
      preferred_ho4: false,
      primary_address: {
        street_number: addr&.street_number,
        street_name: addr&.street_name,
        city: addr&.city,
        state: addr&.state,
        country: addr&.country,
        county: addr&.county,
        zip_code: addr&.zip_code
      }
    }
  }
end)
json.policy_users_attributes [
	{ 
		primary: true, 
		spouse: false, 
		user_attributes: {
			email: nil,
			profile_attributes: {
				first_name: nil,
				last_name: nil,
				contact_phone: nil,
				birth_date: nil,
				job_title: nil
			}
		}
	}
]
