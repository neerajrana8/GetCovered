json.partial! 'v2/shared/master_policies/master_policy_index_fields.json.jbuilder', master_policy: master_policy

json.carrier master_policy.carrier

json.agency master_policy.agency

json.account master_policy.account

json.policy_coverages master_policy.policy_coverages

json.policy_type_title master_policy&.policy_type&.title
