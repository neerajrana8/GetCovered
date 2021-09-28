json.partial! "v2/staff_account/insurables/insurable_index_fields.json.jbuilder",
  insurable: insurable

json.account_title insurable.account&.title
json.agency_title  insurable.agency&.title
json.tenants(insurable.leases.current.map { |lease| lease.primary_user&.profile&.full_name }.compact)
