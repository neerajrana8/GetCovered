json.partial! "v2/staff_agency/policies/policy_show_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.primary_user policy.primary_user

json.additional_users policy.not_primary_users

json.policy_coverages policy.coverages

json.primary_insurable policy.primary_insurable

json.premium policy.premium