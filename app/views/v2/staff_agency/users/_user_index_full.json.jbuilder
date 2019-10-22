json.partial! "v2/staff_agency/users/user_index_fields.json.jbuilder",
  user: user


json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/staff_agency/profiles/profile_short_fields.json.jbuilder",
      profile: user.profile
  end
end
