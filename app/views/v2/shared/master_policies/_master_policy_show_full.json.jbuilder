json.partial! 'v2/shared/policies/fields.json.jbuilder', policy: master_policy

json.carrier master_policy.carrier

json.agency master_policy.agency

json.account master_policy.account

json.policy_coverages master_policy.policy_coverages
json.policy_type_title I18n.t("policy_type_model.#{master_policy.policy_type&.title&.parameterize&.underscore}")

json.policy_premium do
  json.merge! master_policy&.policy_premiums&.last&.attributes
  json.base master_policy&.policy_premiums&.last&.policy_premium_items&.last&.total_due
end

#json.policy_premium master_policy.policy_premiums.last

if PolicyType::MASTER_IDS.include?(master_policy.policy_type_id)
  json.update_available master_policy.policies.blank?
end

# TODO: Needs to be changed after refactoring
json.base master_policy&.policy_premiums&.last&.policy_premium_items&.last&.total_due
