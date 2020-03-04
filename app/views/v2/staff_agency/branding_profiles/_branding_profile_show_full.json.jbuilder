json.partial! "v2/staff_agency/branding_profiles/branding_profile_show_fields.json.jbuilder",
  branding_profile: branding_profile


json.profile_attributes do
  unless branding_profile.branding_profile_attributes.nil?
    json.array! branding_profile.branding_profile_attributes
  end
end
