json.partial! "v2/staff_super_admin/users/user_show_fields.json.jbuilder",
  user: user


json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/staff_super_admin/profiles/profile_show_fields.json.jbuilder",
      profile: user.profile
  end
end

json.address do
  if user.address.present?
    json.partial! "v2/staff_super_admin/addresses/address_show_fields.json.jbuilder",
                  address: user.address
  end
end

json.partial! "v2/shared/users/superadmin_user_fields",
              user: user

json.agencies do
  if user.agencies.present?
    json.array! user.agencies do |agency|
      json.id agency.id
      json.title agency.title
    end
  end
end

json.existing_policies user.policies.exists?
json.current_lease user.leases.current.exists?
