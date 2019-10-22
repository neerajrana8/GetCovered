json.partial! "v2/staff_account/leases/lease_index_fields.json.jbuilder",
  lease: lease


json.account do
  unless lease.account.nil?
    json.partial! "v2/staff_account/accounts/account_short_fields.json.jbuilder",
      account: lease.account
  end
end

json.insurable do
  unless lease.insurable.nil?
    json.partial! "v2/staff_account/insurables/insurable_short_fields.json.jbuilder",
      insurable: lease.insurable
  end
end

json.lease_type do
  unless lease.lease_type.nil?
    json.partial! "v2/staff_account/lease_types/lease_type_short_fields.json.jbuilder",
      lease_type: lease.lease_type
  end
end
