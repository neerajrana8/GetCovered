json.partial! "v2/user/insurables/insurable_short_fields.json.jbuilder",
  insurable: insurable


json.addresses_attributes do
  unless insurable.addresses.nil?
    json.array! insurable.addresses do |insurable_addresses|
      json.partial! "v2/user/addresses/address_show_fields.json.jbuilder",
        address: insurable_addresses
    end
  end
end
