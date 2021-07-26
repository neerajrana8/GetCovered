json.partial! 'v2/shared/carrier_agencies/carrier_agency_fields.json.jbuilder', carrier_agency: carrier_agency

json.carrier_agency_authorizations do
  if carrier_agency.carrier_agency_authorizations.any?
    json.array! carrier_agency.carrier_agency_authorizations do |carrier_agency_authorization|
      json.partial! 'v2/shared/carrier_agency_authorizations/carrier_agency_authorization_full.json.jbuilder',
                    carrier_agency_authorization: carrier_agency_authorization
    end
  end

  if carrier_agency.carrier_agency_policy_types.any?
    json.array! carrier_agency.carrier_agency_policy_types do |carrier_agency_policy_type|
      json.partial! 'v2/shared/carrier_agency_policy_types/full.json.jbuilder',
                    carrier_agency_policy_type: carrier_agency_policy_type
    end
  end
end
