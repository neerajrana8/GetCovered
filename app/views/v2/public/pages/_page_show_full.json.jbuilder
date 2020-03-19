json.partial! "v2/public/pages/page_show_fields.json.jbuilder",
  page: page

json.branding_profile do
  json.partial! "v2/public/branding_profiles/branding_profile_show_full.json.jbuilder", branding_profile: page.branding_profile
end