json.partial! 'v2/shared/policies/fields.json.jbuilder', policy: master_policy_coverage

if master_policy_coverage.insurables.any?
  json.insurable master_policy_coverage.insurables.take,
                 partial: 'v2/shared/master_policies/insurable_full.json.jbuilder',
                 as: :insurable
end
