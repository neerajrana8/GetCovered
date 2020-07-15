json.partial! "v2/staff_account/insurables/insurable_show_fields.json.jbuilder",
              insurable: insurable

json.account do
  unless insurable.account.nil?
    json.partial! "v2/staff_account/accounts/account_short_fields.json.jbuilder",
                  account: insurable.account
  end
end

json.addresses_attributes do
  unless insurable.addresses.nil?
    json.array! insurable.addresses do |insurable_addresses|
      json.partial! "v2/staff_account/addresses/address_show_fields.json.jbuilder",
                    address: insurable_addresses
    end
  end
end

json.policies do
  unless insurable.policies.nil?
    json.array! insurable.policies do |policy|
      json.partial! "v2/staff_account/policies/policy_short_fields.json.jbuilder", policy: policy
    end
  end
end

json.carrier_insurable_profiles do
  unless insurable.carrier_insurable_profiles.nil?
    json.array! insurable.carrier_insurable_profiles do |insurable_carrier_insurable_profile|
      json.partial! "v2/staff_account/carrier_insurable_profiles/carrier_insurable_profile_show_fields.json.jbuilder",
                    carrier_insurable_profile: insurable_carrier_insurable_profile
    end
  end
end

json.assignments insurable.assignments do |assignment|
  json.partial! "v2/staff_account/assignments/assignment_short_fields.json.jbuilder", assignment: assignment
end

json.insurable_type do
  json.partial! 'v2/staff_account/insurable_types/insurable_type_short_fields.json.jbuilder',
                insurable_type: insurable.insurable_type
end

json.parent_community do
  if insurable.parent_community_for_all.present?
    json.partial! 'v2/staff_account/insurables/insurable_short_fields.json.jbuilder',
                  insurable: insurable.parent_community_for_all
  end
end

json.parent_building do
  if insurable.parent_building.present?
    json.partial! 'v2/staff_account/insurables/insurable_short_fields.json.jbuilder',
                  insurable: insurable.parent_building
  end
end

json.buildings_count insurable&.buildings&.count
json.units_count insurable&.insurables&.where(insurable_type_id: InsurableType::UNITS_IDS)&.count

json.can_be_covered insurable.policies.current.empty?
