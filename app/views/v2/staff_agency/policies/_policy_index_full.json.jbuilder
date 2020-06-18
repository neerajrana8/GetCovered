json.partial! "v2/staff_agency/policies/policy_index_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.agency policy.agency

json.account policy.account

json.policy_type_title policy&.policy_type&.title