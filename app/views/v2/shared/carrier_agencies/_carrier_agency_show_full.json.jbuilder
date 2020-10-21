json.partial! 'v2/shared/carrier_agencies/carrier_agency_fields.json.jbuilder', carrier_agency: carrier_agency

json.carrier_agency_authorizations do
  if carrier_agency.carrier_agency_authorizations.any?
    json.array! carrier_agency.carrier_agency_authorizations do |carrier_agency_authorization|
      json.partial! 'v2/shared/carrier_agency_authorizations/carrier_agency_authorization_full.json.jbuilder',
                    carrier_agency_authorization: carrier_agency_authorization
    end
  end
end
