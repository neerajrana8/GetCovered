json.partial! "v2/staff_super_admin/agencies/agency_show_fields.json.jbuilder",
  agency: agency


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
