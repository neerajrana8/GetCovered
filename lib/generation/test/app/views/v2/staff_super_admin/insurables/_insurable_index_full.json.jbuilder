json.partial! "v2/staff_super_admin/insurables/insurable_index_fields.json.jbuilder",
  insurable: insurable


json.account do
  unless insurable.account.nil?
    json.partial! "v2/staff_super_admin/accounts/account_short_fields.json.jbuilder",
      account: insurable.account
  end
end

json.carrier_insurable_profiles do
  unless insurable.carrier_insurable_profiles.nil?
    json.array! insurable.carrier_insurable_profiles do |insurable_carrier_insurable_profiles|
      json.partial! "v2/staff_super_admin/carrier_insurable_profiles/carrier_insurable_profile_show_fields.json.jbuilder",
        carrier_insurable_profile: insurable_carrier_insurable_profiles
    end
  end
end
