json.communities do
  json.array! @communities.each do |community|
    json.title community[:title]
    json.account_title community[:account_title]
    json.total_units community[:total_units]
    json.expired_policies community[:expired_policies]
  end
end
