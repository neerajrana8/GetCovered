json.partial! "v2/staff_agency/policies/policy_show_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.primary_user do
  json.partial! "v2/staff_agency/users/user_show_full.json.jbuilder",
        user: policy.primary_user
end


json.additional_users do
  json.array! policy.not_primary_users do |user|
      json.partial! "v2/staff_agency/users/user_show_full.json.jbuilder",
        user: user
  end
end

json.policy_coverages policy.coverages

json.primary_insurable policy.primary_insurable

json.premium policy.premium