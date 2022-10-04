json.extract! user, :id, :email, :created_at, :has_leases, :has_existing_policies, :has_current_leases

# TODO: Remove Legacy format "_attributes"
json.profile_attributes user.profile
json.accounts(user.accounts.collect { |a| { title: a.title, id: a.id } })
json.address do
  if user.address.present?
    json.extract! user.address, :addressable_id, :addressable_type, :city,
                  :country, :county, :full, :id, :latitude, :longitude, :plus_four,
                  :state, :street_name, :street_number, :street_two, :timezone,
                  :zip_code
  end
end
json.agencies(user.agencies.uniq.collect { |a| { title: a.title, id: a.id } })
json.communities(
  user.insurables.uniq.collect do |a|
    next if !a.insurable_id.nil?
    { title: a.title, id: a.id }
  end.compact!
)
