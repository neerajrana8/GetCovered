json.partial! "v2/user/leases/lease_show_fields.json.jbuilder",
  lease: lease


json.insurable do
  unless lease.insurable.nil?
    json.partial! "v2/user/insurables/insurable_short_fields.json.jbuilder",
      insurable: lease.insurable
  end
end

json.lease_type do
  unless lease.lease_type.nil?
    json.partial! "v2/user/lease_types/lease_type_short_fields.json.jbuilder",
      lease_type: lease.lease_type
  end
end
