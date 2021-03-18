json.array! @communities_data.each do |community|
  json.id community[:id]
  json.title community[:title]
  json.account_title community[:account_title]
  json.total_units community[:total_units]
  json.uninsured_units community[:uninsured_units]
  json.expiring_policies community[:expiring_policies]
end
