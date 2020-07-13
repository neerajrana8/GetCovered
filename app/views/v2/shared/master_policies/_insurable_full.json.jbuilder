json.partial! 'v2/shared/master_policies/insurable_fields.json.jbuilder', insurable: insurable

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
