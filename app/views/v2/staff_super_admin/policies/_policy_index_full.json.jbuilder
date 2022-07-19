json.partial! "v2/staff_super_admin/policies/policy_index_fields.json.jbuilder",
  policy: policy

json.carrier do
  json.title policy.carrier&.title
end

#TODO: temp fix for pma policies
json.agency do
  if policy.agency.present?
    json.title policy.agency&.title
  else
    if policy.insurables&.last&.agency.present?
      json.title policy.insurables&.last&.agency&.title
    else
      json.title policy.insurables&.last&.account&.agency&.title
    end
  end
end

json.account do
  if policy.account.present?
    json.title policy.account&.title
  else
    json.title policy.insurables&.last&.account&.title
  end
end

json.policy_type_title policy&.policy_type&.title

# json.primary_insurable do
#   unless policy.primary_insurable.nil?
#     json.partial! "v2/staff_agency/insurables/insurable_short_fields.json.jbuilder",
#                   insurable: policy.primary_insurable
#
#   end
# end

json.primary_user do
  if policy.primary_user.present?
    json.email policy.primary_user.email
    json.full_name policy.primary_user.profile.full_name
  end
end
# FIXME: Possible wrong constraint logic: duplicate key value violates unique constraint "index_policy_quotes_on_external_id"
#json.billing_strategy policy.policy_quotes&.last&.policy_application&.billing_strategy&.title
