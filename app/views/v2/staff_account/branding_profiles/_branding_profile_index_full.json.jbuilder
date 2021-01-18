json.partial! "v2/staff_account/branding_profiles/branding_profile_index_fields.json.jbuilder",
  branding_profile: branding_profile

json.profile_attributes do
  json.array! branding_profile&.branding_profile_attributes
end
