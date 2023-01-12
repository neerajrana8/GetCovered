json.extract! user, :id, :email

json.profile_attributes do
  json.partial! "v2/staff_super_admin/profiles/profile_show_fields.json.jbuilder",
    profile: user.profile unless user.profile.nil?
end

# Skip addresses for now. Dylan is working on it.
# json.address_attributes do
#   json.array! user.addresses do |addr|
#     json.partial! "v1/user/addresses/address",
#       address: addr
#   end
# end
