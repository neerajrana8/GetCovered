json.partial! 'v2/staff_account/master_policies/master_policy_show_fields.json.jbuilder', master_policy: master_policy

json.carrier master_policy.carrier

json.agency master_policy.agency

json.account master_policy.account

json.policy_coverages master_policy.policy_coverages

json.master_policy_coverages do
  if master_policy_coverages.present?
    json.array! master_policy_coverages, partial: 'v2/staff_account/master_policies/master_policy_index_full.json.jbuilder', as: :master_policy
  end
end

