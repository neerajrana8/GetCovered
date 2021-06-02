json.partial! "v2/staff_account/policies/policy_index_fields.json.jbuilder",
  policy: policy

json.carrier do
  json.title policy.carrier&.title
end

json.agency do
  json.title policy.agency&.title
end

json.policy_type_title policy&.policy_type&.title

json.primary_user do
  if policy.primary_user.present?
    json.email policy.primary_user.email
    json.full_name policy.primary_user.profile&.full_name
  end
end
