json.partial! 'v2/public/policies/policy_show_fields.json.jbuilder',
  policy: policy

json.account do
  unless policy.account.nil?
    json.partial! 'v2/user/accounts/account_short_fields.json.jbuilder',
      account: policy.account
  end
end

json.policy_application do
  if policy.policy_application.present?
    json.partial! 'v2/staff_agency/policy_applications/policy_application_show_fields.json.jbuilder',
                  policy_application: policy.policy_application
  end
end

json.agency do
  unless policy.agency.nil?
    json.partial! 'v2/user/agencies/agency_short_fields.json.jbuilder',
      agency: policy.agency
  end
end

json.carrier do
  unless policy.carrier.nil?
    json.partial! 'v2/user/carriers/carrier_short_fields.json.jbuilder',
      carrier: policy.carrier
  end
end

json.coverages do
  unless policy.coverages.nil?
    json.array! policy.coverages do |policy_coverages|
      json.partial! 'v2/user/policy_coverages/policy_coverage_short_fields.json.jbuilder',
        policy_coverage: policy_coverages
    end
  end
end

json.policy_premiums_attributes do
  unless policy.policy_premiums.nil?
    json.array! policy.policy_premiums do |policy_policy_premiums|
      json.partial! 'v2/user/policy_premia/policy_premium_short_fields.json.jbuilder',
        policy_premium: policy_policy_premiums
    end
  end
end

json.policy_type do
  unless policy.policy_type.nil?
    json.partial! 'v2/user/policy_types/policy_type_short_fields.json.jbuilder',
      policy_type: policy.policy_type
  end
end

json.insurables do
  #unless policy.residential?
    json.array! policy.insurables do |insurable|
      json.partial! 'v2/user/insurables/insurable_select_full.json.jbuilder', insurable: insurable
    end
  #end
end

json.change_requests do
  json.array! policy.change_requests do |change_request|
    json.partial! 'v2/shared/change_requests/full.json.jbuilder', change_request: change_request
  end
end

json.documents policy.documents do |document|
  json.id document.id
  json.filename document.filename
  json.url link_to_document(document)
  json.preview_url link_to_document_preview(document) if document.variable?
end
