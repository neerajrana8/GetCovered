json.partial! "v2/shared/carrier_agencies/carrier_agency_fields.json.jbuilder",
  carrier_agency: carrier_agency

json.carrier_agency_policy_types do
  if carrier_agency.carrier_agency_policy_types.any?
    json.array! carrier_agency.carrier_agency_policy_types do |carrier_agency_policy_type|
      json.partial! 'v2/shared/carrier_agency_policy_types/full.json.jbuilder',
                    carrier_agency_policy_type: carrier_agency_policy_type
    end
  end
end
