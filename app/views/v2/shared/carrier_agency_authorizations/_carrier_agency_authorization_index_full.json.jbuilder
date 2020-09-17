json.partial! 'v2/shared/carrier_agency_authorizations/carrier_agency_authorization_index_fields.json.jbuilder',
              carrier_agency_authorization: carrier_agency_authorization

json.agency_id carrier_agency_authorization.agency.id
json.carrier_id carrier_agency_authorization.carrier.id
