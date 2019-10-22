json.partial! "v2/staff_agency/accounts/account_index_fields.json.jbuilder",
  account: account


json.agency do
  unless account.agency.nil?
    json.partial! "v2/staff_agency/agencies/agency_short_fields.json.jbuilder",
      agency: account.agency
  end
end
