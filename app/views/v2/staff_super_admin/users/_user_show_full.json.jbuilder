json.partial! "v2/staff_super_admin/users/user_show_fields.json.jbuilder",
  user: user


json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/staff_super_admin/profiles/profile_show_fields.json.jbuilder",
      profile: user.profile
  end
end
