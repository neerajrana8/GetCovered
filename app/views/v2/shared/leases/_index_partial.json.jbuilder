json.partial! 'v2/shared/leases/fields.json.jbuilder', lease: lease

json.account do
  unless lease.account.nil?
    json.partial! 'v2/staff_super_admin/accounts/account_short_fields.json.jbuilder',
                  account: lease.account
  end
end

json.agency lease&.account&.agency

json.insurable do
  if lease.insurable.present?
    json.partial! 'v2/shared/insurables/index_partial.json.jbuilder',
                  insurable: lease.insurable
  end
end

json.lease_type do
  unless lease.lease_type.nil?
    json.partial! 'v2/staff_super_admin/lease_types/lease_type_short_fields.json.jbuilder',
                  lease_type: lease.lease_type
  end
end
