case policy.carrier&.integration_designation
when 'msi'
  json.policy_coverages do
    json.partial! 'v2/shared/policies/policy_coverages/msi.json.jbuilder', policy_coverages: policy.policy_coverages
  end
else
  json.policy_coverages policy.coverages
end
