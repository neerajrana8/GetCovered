json.partial! "v2/staff_super_admin/policies/policy_index_fields.json.jbuilder",
  policy: policy

json.agency do
  json.title policy.agency&.title
end

json.account do
  json.title policy.account&.title
end

json.primary_user do
  if policy.primary_user.present?
    json.email policy.primary_user.email
  end
end