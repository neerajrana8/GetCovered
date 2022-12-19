json.partial! "v2/staff_super_admin/insurables/insurable_show_fields.json.jbuilder",
  insurable: insurable


json.account do
  unless insurable.account.nil?
    json.partial! "v2/staff_super_admin/accounts/account_short_fields.json.jbuilder",
      account: insurable.account
  end
end

json.addresses_attributes do
  unless insurable.addresses.nil?
    json.array! insurable.addresses do |insurable_addresses|
      json.partial! "v2/staff_super_admin/addresses/address_show_fields.json.jbuilder",
        address: insurable_addresses
    end
  end
end

json.policies do
  unless insurable.policies.nil?
    json.array! insurable.policies do |policy|
      json.extract! policy, :id, :number, :policy_type_id, :status, :created_at, :effective_date, :expiration_date

      json.policy_type_title I18n.t("policy_type_model.#{policy&.policy_type&.title&.parameterize&.underscore}")

      if PolicyType::MASTER_COVERAGES_IDS.include?(policy.policy_type_id) && policy.policy.present?
        json.master_policy do
          json.extract! policy.policy, :id, :number, :policy_type_id, :status, :created_at, :effective_date, :expiration_date

          json.policy_type_title I18n.t("policy_type_model.#{policy.policy&.policy_type&.title&.parameterize&.underscore}")
        end
      end
    end
  end
end

json.carrier_insurable_profiles do
  unless insurable.carrier_insurable_profiles.nil?
    json.array! insurable.carrier_insurable_profiles do |insurable_carrier_insurable_profiles|
      json.partial! "v2/staff_super_admin/carrier_insurable_profiles/carrier_insurable_profile_short_fields.json.jbuilder",
        carrier_insurable_profile: insurable_carrier_insurable_profiles
    end
  end
end

json.assignments insurable.assignments do |assignment|
  json.partial! "v2/staff_super_admin/assignments/assignment_short_fields.json.jbuilder", assignment: assignment
end


json.insurable_type do
  json.partial! 'v2/staff_super_admin/insurable_types/insurable_type_short_fields.json.jbuilder',
                insurable_type: insurable.insurable_type
end

json.parent_community do
  if insurable.parent_community_for_all.present?
    json.partial! 'v2/staff_super_admin/insurables/insurable_short_fields.json.jbuilder',
                  insurable: insurable.parent_community_for_all
  end
end

json.parent_building do
  if insurable.parent_building.present?
    json.partial! 'v2/staff_super_admin/insurables/insurable_short_fields.json.jbuilder',
                  insurable: insurable.parent_building
  end
end

json.buildings_count insurable&.buildings&.count
json.units_count insurable&.insurables&.where(insurable_type_id: InsurableType::UNITS_IDS)&.count

json.active_master_policy do
  if @master_policy.present?
    json.partial! 'v2/shared/policies/fields.json.jbuilder', policy: @master_policy
  end
end

json.active_master_policy_coverage do
  if @master_policy_coverage.present?
    json.partial! 'v2/shared/policies/fields.json.jbuilder', policy: @master_policy_coverage
  end
end

json.account_agency do
  if insurable.account&.agency&.present?
    json.id insurable.account.agency.id
    json.title insurable.account.agency.title
  end
end

json.agency do
  if insurable.agency.present?
    json.id insurable.agency.id
    json.title insurable.agency.title
  end
end

json.master_policy_configurations insurable.master_policy_configurations
