json.partial! "v2/public/policies/policy_index_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.documents policy.documents do |document|
  json.id document.id
  json.filename document.filename
  json.url link_to_document(document)
  json.preview_url link_to_document_preview(document) if document.variable?
end
