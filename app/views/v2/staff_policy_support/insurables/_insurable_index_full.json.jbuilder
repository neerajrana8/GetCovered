json.partial! 'v2/staff_policy_support/insurables/insurable_index_fields.json.jbuilder',
              insurable: insurable

#json.account do
#  unless insurable.account.nil?
#    json.partial! 'v2/staff_policy_support/accounts/account_short_fields.json.jbuilder',
#                  account: insurable.account
#  end
#end

# TODO: Refactoring
json.parent_building do
  if insurable.parent_building.present?
    json.partial! 'v2/staff_super_admin/insurables/insurable_short_fields.json.jbuilder',
                  insurable: insurable.parent_building
  end
end

json.account_title insurable.account&.title
json.agency_title  insurable.agency&.title
json.parent_community  insurable.parent_community_for_all&.title
json.parent_building  insurable.parent_building&.title
json.tenants(insurable.leases.current.map { |lease| lease.primary_user&.profile&.full_name }.compact)
