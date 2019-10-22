json.partial! "v2/staff_account/accounts/account_show_fields.json.jbuilder",
  account: account


json.addresses_attributes do
  unless account.addresses.nil?
    json.array! account.addresses do |account_addresses|
      json.partial! "v2/staff_account/addresses/address_show_fields.json.jbuilder",
        address: account_addresses
    end
  end
end

json.agency do
  unless account.agency.nil?
    json.partial! "v2/staff_account/agencies/agency_short_fields.json.jbuilder",
      agency: account.agency
  end
end

json.branding_profiles do
  unless account.branding_profiles.nil?
    json.array! account.branding_profiles do |account_branding_profiles|
      json.partial! "v2/staff_account/branding_profiles/branding_profile_index_fields.json.jbuilder",
        branding_profile: account_branding_profiles
    end
  end
end
