json.extract! user, :id, :email, :created_at, :profile
json.has_existing_policies user.has_existing_policies?
json.has_current_leases user.has_current_leases?

json.accounts(user.accounts.collect { |a| { title: a.title, id: a.id } })

json.agencies(user.agencies.uniq.collect { |a| { title: a.title, id: a.id } })
json.communities(
  user.insurables.uniq.collect do |a|
    next if !a.insurable_id.nil?
    { title: a.title, id: a.id }
  end.compact!
)
