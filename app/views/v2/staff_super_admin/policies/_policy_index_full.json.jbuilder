json.partial! "v2/staff_super_admin/policies/policy_index_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.agency policy.agency

json.account policy.account

json.policy_type_title policy&.policy_type&.title

json.primary_campaign_name policy.primary_user&.lead&.tracking_url&.campaign_name

json.premium_total policy.policy_quotes&.last&.policy_premium&.total

json.premium_first policy.policy_quotes&.last&.invoices&.first&.total

json.billing_strategy policy.policy_quotes&.last&.policy_premium&.billing_strategy&.title
