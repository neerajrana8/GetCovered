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
    json.array! user.accounts.distinct do |account|
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
    json.array! subagencies do |agency|
      json.id agency.id
      json.title agency.title
    end
  end
  json.agencies do
    json.array! agencies do |agency|
      json.id agency.id
      json.title agency.title
    end
  end
end

json.has_existing_policies user.has_existing_policies?
json.has_current_leases user.has_current_leases?

community_titles = []
user.insurables.each  do |insurable|
  community_titles << insurable.parent_community_for_all.title
end

json.community_titles community_titles
