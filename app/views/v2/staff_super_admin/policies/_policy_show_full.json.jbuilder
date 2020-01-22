json.partial! "v2/staff_super_admin/policies/policy_show_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.users do
  json.array! policy.policy_users do |policy_user|
    json.primary policy_user.primary
    json.spouse policy_user.spouse
    json.partial! "v2/staff_super_admin/users/user_show_full.json.jbuilder", user: policy_user.user
  end
end

json.policy_coverages policy.coverages

json.primary_insurable policy.primary_insurable

json.premium policy.premium