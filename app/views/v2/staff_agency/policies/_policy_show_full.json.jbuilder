json.partial! "v2/staff_agency/policies/policy_show_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.users do
  json.array! policy.policy_users do |policy_user|
    json.primary policy_user.primary
    json.spouse policy_user.spouse
    json.partial! "v2/staff_agency/users/user_show_full.json.jbuilder", user: policy_user.user
  end
end

json.policy_coverages policy.coverages

json.primary_insurable policy.primary_insurable

json.premium policy.premium

json.documents policy.documents do |document|
  json.id document.id
  json.filename document.filename
  json.url link_to_document(document)
  json.preview_url link_to_document_preview(document) if document.variable?
end
