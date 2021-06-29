json.partial! 'v2/shared/master_policies/insurable_fields.json.jbuilder', insurable: insurable

json.insurable_type insurable.insurable_type.title

json.community do
  if insurable.parent_community_for_all.present?
    json.partial! 'v2/shared/master_policies/insurable_fields.json.jbuilder', insurable: insurable.parent_community_for_all
  end
end

json.building do
  if insurable.parent_building.present?
    json.partial! 'v2/shared/master_policies/insurable_fields.json.jbuilder', insurable: insurable.parent_building
  end
end

json.active_master_policy do
  if insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS + PolicyType::MASTER_COVERAGES_IDS).any?
    json.partial! 'v2/shared/policies/fields.json.jbuilder',
                  policy: insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS + PolicyType::MASTER_COVERAGES_IDS).take
  end
end

json.auto_assign_policies insurable.policy_insurables.where(policy: @master_policy).take&.auto_assign
