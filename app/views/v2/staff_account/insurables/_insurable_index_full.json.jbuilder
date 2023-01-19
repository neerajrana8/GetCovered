json.partial! "v2/staff_account/insurables/insurable_index_fields.json.jbuilder",
  insurable: insurable

json.parent_building do
  if insurable.parent_building.present?
    json.partial! 'v2/staff_super_admin/insurables/insurable_short_fields.json.jbuilder',
                  insurable: insurable.parent_building
  end
end

json.account_title insurable.account&.title
json.agency_title  insurable.agency&.title
json.tenants(insurable.leases.current.map { |lease| lease.primary_user&.profile&.full_name }.compact)
