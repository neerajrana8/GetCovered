json.partial! 'v2/shared/users/fields.json.jbuilder',
              user: user

json.profile_attributes do
  unless user.profile.nil?
    json.partial! 'v2/shared/profiles/fields.json.jbuilder',
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

if user.agencies.present?
  subagencies = []
  agencies = []
  user.agencies.each do |agency|
    if agency.agency_id.present?
      subagencies << agency
      agencies << agency.agency
    else
      agencies << agency
    end
  end
  subagencies = subagencies.uniq
  agencies = agencies.uniq
  json.subagencies do
    json.partial! 'v2/shared/agencies/agencies', agencies: subagencies
  end
  json.agencies do
    json.partial! 'v2/shared/agencies/agencies', agencies: agencies
  end
end

json.has_existing_policies user.has_existing_policies?
json.has_current_leases user.has_current_leases?

communities = []
user.insurables.each  do |insurable|
  parent_community = insurable.parent_community_for_all
  communities << {id: parent_community.id, title: parent_community.title}
end

json.communities communities

json.address do
  if user.address.present?
    json.partial! 'v2/shared/addresses/fields.json.jbuilder',
                  address: user.address
  end
end
