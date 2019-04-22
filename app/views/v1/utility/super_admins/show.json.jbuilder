json.extract! @resource, :id, :email, :settings, :created_at, :updated_at

json.profile_attributes do
  json.partial! "v1/utility/profiles/profile", 
    profile: @resource.profile unless @resource.profile.nil?
end
