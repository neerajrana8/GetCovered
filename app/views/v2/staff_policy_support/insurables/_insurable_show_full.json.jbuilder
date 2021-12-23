json.partial! "v2/staff_policy_support/insurables/insurable_show_fields.json.jbuilder",
  insurable: insurable

json.addresses_attributes do
  unless insurable.addresses.nil?
    json.array! insurable.addresses do |insurable_addresses|
      json.partial! "v2/staff_policy_support/addresses/address_show_fields.json.jbuilder",
        address: insurable_addresses
    end
  end
end

json.parent_community do
  if insurable.parent_community_for_all.present?
    json.partial! 'v2/staff_policy_support/insurables/insurable_short_fields.json.jbuilder',
                  insurable: insurable.parent_community_for_all
  end
end

json.parent_building do
  if insurable.parent_building.present?
    json.partial! 'v2/staff_policy_support/insurables/insurable_short_fields.json.jbuilder',
                  insurable: insurable.parent_building
  end
end
