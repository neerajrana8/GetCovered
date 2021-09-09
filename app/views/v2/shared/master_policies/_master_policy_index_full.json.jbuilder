json.partial! 'v2/shared/policies/fields.json.jbuilder', policy: master_policy

json.carrier master_policy.carrier

json.agency master_policy.agency

json.account master_policy.account

json.policy_coverages master_policy.policy_coverages

json.policy_type_title I18n.t("policy_type_model.#{master_policy&.policy_type&.title&.parameterize&.underscore}")
