json.partial! "v2/staff_agency/users/user_index_fields.json.jbuilder",
  user: user


json.profile_attributes do
  unless user.profile.nil?
    json.partial! "v2/staff_agency/profiles/profile_short_fields.json.jbuilder",
      profile: user.profile
  end
end

json.accounts do
  if user.accounts
    json.array! user.accounts do |account|
      json.partial! "v2/shared/accounts/account_short_fields",
                    account: account
    end
  end
end

subagencies = user.agencies.map{|agency| agency unless agency.eql?(current_staff.organizable)}.compact
if subagencies.present?
  json.subagencies do
    json.partial! "v2/shared/agencies/agencies",
                agencies: subagencies
  end
end
