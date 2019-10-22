json.partial! "v2/user/users/user_show_fields.json.jbuilder",
  user: user


json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/user/profiles/profile_show_fields.json.jbuilder",
      profile: user.profile
  end
end
