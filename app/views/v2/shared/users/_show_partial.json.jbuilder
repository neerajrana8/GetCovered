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

json.existing_policies user.policies.exists?
json.current_lease user.leases.current.exists?

community_titles = []
user.insurables.each  do |insurable|
  community_titles << insurable.parent_community_for_all.title
end

json.community_titles community_titles
