json.partial! "v2/public/branding_profiles/branding_profile_show_fields.json.jbuilder",
  branding_profile: branding_profile


json.profile_attributes do
  json.array! branding_profile&.branding_profile_attributes
end

json.pages do
  json.array! branding_profile&.pages do |page|
    json.id page.id
    json.title page.title
  end
end

json.profileable_title branding_profile.profileable.title if branding_profile.profileable.respond_to?(:title)

case branding_profile.profileable
when Account
  json.agency_id branding_profile.profileable.agency_id
  json.account_id branding_profile.profileable_id
when Agency
  json.agency_id branding_profile.profileable_id
end
