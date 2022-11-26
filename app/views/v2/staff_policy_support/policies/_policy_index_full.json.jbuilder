json.partial! "v2/staff_super_admin/policies/policy_index_fields.json.jbuilder",
  policy: policy

#TODO: temp fix for pma policies
json.agency do
  if policy.agency.present?
    json.title policy.agency&.title
  else
    if policy.insurables&.last&.agency.present?
      json.title policy.insurables&.last&.agency&.title
    else
      json.title policy.insurables&.last&.account&.agency&.title
    end
  end
end

json.account do
  if policy.account.present?
    json.title policy.account&.title
  else
    json.title policy.insurables&.last&.account&.title
  end
end

# TODO add primary_insurable
json.primary_insurable do
  unless policy.primary_insurable.nil?
    json.partial! "v2/staff_policy_support/insurables/insurable_short_fields.json.jbuilder",
                  insurable: policy.primary_insurable
    json.parent_community do
      if policy.primary_insurable.parent_community_for_all.present?
        json.partial! 'v2/staff_policy_support/insurables/insurable_short_fields.json.jbuilder',
                      insurable: policy.primary_insurable.parent_community_for_all
      end
    end
    json.parent_building do
      if policy.primary_insurable.parent_building.present?
        json.partial! 'v2/staff_policy_support/insurables/insurable_short_fields.json.jbuilder',
                      insurable: policy.primary_insurable.parent_building
      end
    end
  end
end


json.primary_user do
  if policy.primary_user.present?
    json.email policy.primary_user.email
    json.full_name policy.primary_user.profile&.full_name
  end
end
