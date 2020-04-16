policy_type = PolicyType.create(title: "Rent Guarantee", designation: "RENT-GUARANTEE", enabled: true)
carrier = Carrier.create(title: "Pensio", integration_designation: 'pensio', syncable: false, rateable: false, quotable: true, bindable: true, verifiable: false, enabled: true)
get_covered = Agency.find(1)

carrier_policy_type = CarrierPolicyType.create!(
  carrier: carrier,
  policy_type: policy_type,
	application_required: true,
	application_fields: {
		"monthly_rent": 0,
		"guarantee_option": 3,
		landlord: {
  	  "company": nil,
  	  "first_name": nil,
  	  "last_name": nil,
  	  "phone_number": nil,
  	  "email": nil	
		},
		employment: {
			primary_applicant: {
				"employment_type": nil,
				"job_description": nil,
				"monthly_income": nil,
				"company_name": nil,
				"company_phone_number": nil,
				"address": {
        		"street_number": nil,
        		"street_name": nil,
        		"street_two": nil,
        		"city": nil,
        		"state": nil,
        		"county": nil,
        		"zip_code": nil,
        		"country": nil
				}       				
			},
			secondary_applicant: {
				"employment_type": nil,
				"job_description": nil,
				"monthly_income": nil,
				"company_name": nil,
				"company_phone_number": nil,
				"address": {
        		"street_number": nil,
        		"street_name": nil,
        		"street_two": nil,
        		"city": nil,
        		"state": nil,
        		"county": nil,
        		"zip_code": nil,
        		"country": nil
				}       				
			}
		}   				
	}
)

51.times do |state|
  available = state == 0 || state == 11 ? false : true
  carrier_policy_availability = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: carrier_policy_type)
end

carrier.agencies << get_covered

get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: nil, new_business: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], payments_per_term: 12, remainder_added_to_deposit: true }, carrier: carrier, policy_type: policy_type)