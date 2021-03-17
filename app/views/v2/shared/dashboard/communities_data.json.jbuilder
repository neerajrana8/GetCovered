json.communities do
  json.array! @communities.each do |community|
    json.title community[:title]
    json.account_title community[:account_title]
    json.total_units community[:total_units]
    json.uninsured_units community[:expired_policies]
    json.expiring_policies community[:expired_policies]
  end
end
