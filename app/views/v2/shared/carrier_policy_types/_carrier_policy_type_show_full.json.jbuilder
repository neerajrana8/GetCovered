json.partial! 'v2/shared/carrier_policy_types/carrier_policy_type_show_fields.json.jbuilder',
              carrier_policy_type: carrier_policy_type

json.title carrier_policy_type.policy_type.title

json.carrier_policy_type_availabilities do
  if carrier_policy_type.carrier_policy_type_availabilities.any?
    json.array! carrier_policy_type.carrier_policy_type_availabilities do |carrier_policy_type_availability|
      json.partial! 'v2/shared/carrier_policy_type_availabilities/carrier_policy_type_availability_show_full.json.jbuilder',
                    carrier_policy_type_availability: carrier_policy_type_availability
    end
  end
end
