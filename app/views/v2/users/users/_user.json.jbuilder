json.extract! user, :id, :email, :created_at, :has_leases, :has_existing_policies, :has_current_leases

# TODO: Remove Legacy format "_attributes"
json.profile_attributes user.profile
json.accounts(user.accounts.collect { |a| { title: a.title, id: a.id } })

json.agencies(user.agencies.uniq.collect { |a| { title: a.title, id: a.id } })
json.communities(
  user.insurables.uniq.collect do |a|
    next if !a.insurable_id.nil?
    { title: a.title, id: a.id }
  end.compact!
)
