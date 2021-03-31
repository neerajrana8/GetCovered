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
