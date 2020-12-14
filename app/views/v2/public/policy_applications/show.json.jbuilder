json.extract! @application, :id, :reference, :external_reference,
  :effective_date, :expiration_date, :status, :status_updated_on, 
  :fields, :questions, :carrier_id, :policy_type_id, :agency_id,
  :account_id, :billing_strategy_id, :coverage_selections,
  :resolver_info, :extra_settings

json.policy_rates_attributes []
json.policy_insurables_attributes(@application.policy_insurables) do |policy_insurable|
  json.primary policy_insurable.primary
  json.insurable_attributes do
    json.id policy_insurable.insurable.id
    json.title policy_insurable.insurable.title
    json.preferred_ho4 policy_insurable.insurable.preferred_ho4
    json.account_id policy_insurable.insurable.account_id
    json.agency_id policy_insurable.insurable.agency_id
    json.insurable_type_id policy_insurable.insurable.insurable_type_id
    primadd = policy_insurable.insurable.primary_address
		json.primary_address do
      json.street_number primadd&.street_number
      json.street_name primadd&.street_name
      json.city primadd&.city
      json.state primadd&.state
      json.country primadd&.country
      json.county primadd&.county
      json.zip_code primadd&.zip_code			
		end
  end
end
json.policy_users_attributes(@application.policy_users) do |policy_user|
	json.primary policy_user.primary
	json.spouse policy_user.spouse
	json.user_attributes do
		json.email policy_user.user.email
		json.profile_attributes do
		  json.first_name policy_user.user.profile.first_name
			json.last_name policy_user.user.profile.last_name
			json.contact_phone policy_user.user.profile.contact_phone
			json.birth_date policy_user.user.profile.birth_date
			json.job_title policy_user.user.profile.job_title			
			json.salutation policy_user.user.profile.salutation
			json.gender policy_user.user.profile.gender
		end
		json.address_attributes do
      json.street_number policy_user.user.address&.street_number
      json.street_name policy_user.user.address&.street_name
      json.street_two policy_user.user.address&.street_two
      json.city policy_user.user.address&.city
      json.state policy_user.user.address&.state
      json.country policy_user.user.address&.country
      json.county policy_user.user.address&.county
      json.zip_code policy_user.user.address&.zip_code			
		end
	end
end
