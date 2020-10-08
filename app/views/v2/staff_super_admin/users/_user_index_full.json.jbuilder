json.partial! "v2/staff_super_admin/users/user_index_fields.json.jbuilder",
  user: user


json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/staff_super_admin/profiles/profile_short_fields.json.jbuilder",
      profile: user.profile
  end
end

json.partial! "v2/shared/users/superadmin_user_fields",
              user: user
