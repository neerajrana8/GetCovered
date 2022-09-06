json.extract! branding_profile, :default, :id, :profileable_id,
              :profileable_type, :styles, :url, :logo_url, :footer_logo_url, :second_logo_url, :second_footer_logo_url,
              :subdomain, :logo_jpeg_url, :enabled

json.profile_attributes do
  json.array! branding_profile&.branding_profile_attributes
end

json.pages do
  json.array! branding_profile&.pages
end

json.profileable_title branding_profile.profileable.title if branding_profile.profileable.respond_to?(:title)
