json.partial! 'v2/shared/users/fields.json.jbuilder', user: user

json.profile_attributes do
  json.partial! 'v2/shared/profiles/fields.json.jbuilder', profile: user.profile unless user.profile.nil?
end
