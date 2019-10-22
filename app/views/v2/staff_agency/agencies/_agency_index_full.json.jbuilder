json.partial! "v2/staff_agency/agencies/agency_index_fields.json.jbuilder",
  agency: agency


json.agency do
  unless agency.agency.nil?
    json.partial! "v2/staff_agency/agencies/agency_short_fields.json.jbuilder",
      agency: agency.agency
  end
end
