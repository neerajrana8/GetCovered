json.partial! "v2/staff_super_admin/agencies/agency_show_fields.json.jbuilder",
  agency: agency

json.coverage_report agency.coverage_report

json.addresses_attributes do
  unless agency.addresses.nil?
    json.array! agency.addresses do |agency_addresses|
      json.partial! "v2/staff_super_admin/addresses/address_show_fields.json.jbuilder",
        address: agency_addresses
    end
  end
end

json.agency do
  unless agency.agency.nil?
    json.partial! "v2/staff_super_admin/agencies/agency_short_fields.json.jbuilder",
      agency: agency.agency
  end
end

json.branding_profiles do
  unless agency.branding_profiles.nil?
    json.array! agency.branding_profiles do |agency_branding_profiles|
      json.partial! "v2/staff_super_admin/branding_profiles/branding_profile_index_fields.json.jbuilder",
        branding_profile: agency_branding_profiles
    end
  end
end

json.global_agency_permission do
  if agency.global_agency_permission
    json.partial! 'v2/shared/global_agency_permissions/full.json.jbuilder',
                  global_agency_permission: agency.global_agency_permission

  end
end

json.global_permission do
  if agency.global_permission
    json.partial! 'v2/shared/global_permissions/full.json.jbuilder',
                  global_permission: agency.global_permission,
                  follow: true
  end
end

json.carriers do
  json.array! agency.carriers.each do |carrier|
    json.id carrier.id
    json.title carrier.title
  end
end
