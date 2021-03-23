json.partial! "v2/staff_super_admin/branding_profiles/branding_profile_show_fields.json.jbuilder",
  branding_profile: branding_profile


json.profile_attributes do
  json.array! branding_profile&.branding_profile_attributes
end

json.pages do
  json.array! branding_profile&.pages
end

json.profileable_title branding_profile.profileable.title if branding_profile.profileable.respond_to?(:title)
