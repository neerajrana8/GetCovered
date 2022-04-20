json.partial! "v2/staff_super_admin/policies/policy_index_fields.json.jbuilder",
  policy: policy

#TODO: temp fix for pma policies
json.agency do
  if policy.agency.present?
    json.title policy.agency&.title
  else
    json.title policy.insurables&.last&.agency&.title
  end
end

json.account do
  if policy.account.present?
    json.title policy.account&.title
  else
    json.title policy.insurables&.last&.account&.title
  end
end

json.primary_user do
  if policy.primary_user.present?
    json.email policy.primary_user.email
  end
end
