json.partial! "v2/staff_agency/insurables/insurable_show_fields.json.jbuilder",
  insurable: insurable


json.account do
  unless insurable.account.nil?
    json.partial! "v2/staff_agency/accounts/account_short_fields.json.jbuilder",
      account: insurable.account
  end
end

json.addresses_attributes do
  unless insurable.addresses.nil?
    json.array! insurable.addresses do |insurable_addresses|
      json.partial! "v2/staff_agency/addresses/address_show_fields.json.jbuilder",
        address: insurable_addresses
    end
  end
end

json.carrier_insurable_profiles do
  unless insurable.carrier_insurable_profiles.nil?
    json.array! insurable.carrier_insurable_profiles do |insurable_carrier_insurable_profiles|
      json.partial! "v2/staff_agency/carrier_insurable_profiles/carrier_insurable_profile_short_fields.json.jbuilder",
        carrier_insurable_profile: insurable_carrier_insurable_profiles
    end
  end
end
