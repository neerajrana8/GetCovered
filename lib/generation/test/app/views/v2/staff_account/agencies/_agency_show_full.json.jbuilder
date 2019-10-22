json.partial! "v2/staff_account/agencies/agency_show_fields.json.jbuilder",
  agency: agency


json.branding_profiles do
  unless agency.branding_profiles.nil?
    json.array! agency.branding_profiles do |agency_branding_profiles|
      json.partial! "v2/staff_account/branding_profiles/branding_profile_index_fields.json.jbuilder",
        branding_profile: agency_branding_profiles
    end
  end
end
