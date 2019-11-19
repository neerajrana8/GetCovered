json.extract! @application, :reference, :external_reference,
  :effective_date, :expiration_date, :status, :status_updated_on, 
  :fields, :questions, :carrier_id, :policy_type_id, :agency_id,
  :account_id, :billing_strategy_id

json.policy_rates []
json.policy_insurables_attributes []
json.policy_users [
	{ 
		primary: true, 
		spouse: false, 
		user_attributes: {
			email: nil,
			profile_attributes: {
				first_name: nil,
				last_name: nil,
				contact_phone: nil,
				birth_date: nil
			}
		}
	}
]