json.partial! "v2/staff_policy_support/accounts/account_index_fields.json.jbuilder",
  account: account


json.agency do
  unless account.agency.nil?
    json.partial! "v2/staff_super_admin/agencies/agency_short_fields.json.jbuilder",
      agency: account.agency
  end
end
json.primary_address account.primary_address
