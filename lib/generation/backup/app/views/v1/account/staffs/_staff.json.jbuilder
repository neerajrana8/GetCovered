json.extract! staff, :id, :email, :settings, :created_at, :updated_at, :notification_options

json.profile_attributes do
  json.partial! "v1/account/profiles/profile", 
    profile: staff.profile unless staff.profile.nil?
end
