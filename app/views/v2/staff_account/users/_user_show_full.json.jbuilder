json.partial! "v2/staff_account/users/user_show_fields.json.jbuilder",
  user: user


json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/staff_account/profiles/profile_show_fields.json.jbuilder",
      profile: user.profile
  end
end

json.address do
  if user.address.present?
    json.partial! "v2/staff_account/addresses/address_show_fields.json.jbuilder",
                  address: user.address
  end
end
