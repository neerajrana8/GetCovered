json.partial! 'v2/shared/policy_types/fields.json.jbuilder', policy_type: policy_type

if policy_type.master?
  json.master_coverages do
    json.array! policy_type.master_coverages, partial: 'v2/shared/policy_types/fields.json.jbuilder', as: :policy_type
  end
end
