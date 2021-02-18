json.partial! "v2/staff_super_admin/insurables/insurable_index_fields.json.jbuilder",
  insurable: insurable


json.account do
  unless insurable.account.nil?
    json.partial! "v2/staff_super_admin/accounts/account_short_fields.json.jbuilder",
      account: insurable.account
  end
end

json.account_title insurable.account&.title
json.agency_title  insurable.agency&.title
