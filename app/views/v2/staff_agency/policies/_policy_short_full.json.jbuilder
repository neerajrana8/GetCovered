json.partial! "v2/staff_agency/policies/policy_short_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.policy_type_title policy&.policy_type&.title