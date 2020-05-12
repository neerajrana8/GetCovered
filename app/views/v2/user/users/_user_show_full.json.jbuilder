json.partial! "v2/user/users/user_show_fields.json.jbuilder",
  user: user

json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/user/profiles/profile_show_fields.json.jbuilder",
      profile: user.profile
  end
end

json.accounts do
  if user.accounts.present?
    json.array! user.accounts do |account|
      json.id account.id
      json.title account.title
      json.agency_id account.agency_id
    end
  end
end


json.address do
  if user.address.present?
    json.partial! "v2/user/addresses/address_show_fields.json.jbuilder",
                  address: user.address
  end
end
