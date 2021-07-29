json.extract! branding_profile, :id, :profileable_id, :profileable_type, :styles, :url, :created_at, :logo_url, :enabled

json.profile_attributes do
  json.array! branding_profile&.branding_profile_attributes
end
