json.partial! "v2/staff_account/users/user_short_fields.json.jbuilder",
  user: user


json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/staff_account/profiles/profile_short_fields.json.jbuilder",
      profile: user.profile
  end
end

json.accounts do
  if user.accounts.present?
    json.array! user.accounts do |account|
      json.id account.id
      json.title account.title
    end
  end
end

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
