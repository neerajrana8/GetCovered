json.partial! "v2/staff_agency/policies/policy_index_fields.json.jbuilder",
  policy: policy

json.carrier do
  json.title policy.carrier&.title
end

json.agency do
  json.title policy.agency&.title
end

json.policy_type_title policy&.policy_type&.title

json.primary_insurable do
  unless policy.primary_insurable.nil?
    json.partial! "v2/staff_agency/insurables/insurable_short_fields.json.jbuilder",
                  insurable: policy.primary_insurable

  end
end

json.primary_user do
  if policy.primary_user.present?
    json.email policy.primary_user.email
    json.full_name policy.primary_user.profile&.full_name
  end
end

# @todo remove after the commissions release
if policy.in_system?
  json.billing_strategy (policy.policy_quotes&.last&.policy_application&.billing_strategy || policy.billing_strategies&.last)&.title
end
