json.partial! "v2/staff_agency/policies/policy_show_fields.json.jbuilder",
  policy: policy

json.carrier policy.carrier

json.agency policy.agency

json.account policy.account

json.policy_application_group_id policy.policy_group&.policy_application_group&.id

json.policy_application do
  if policy.policy_application.present?
    json.partial! 'v2/staff_agency/policy_applications/policy_application_show_fields.json.jbuilder',
                  policy_application: policy.policy_application
  end
end

json.users do
  json.array! policy.policy_users do |policy_user|
    json.primary policy_user.primary
    json.spouse policy_user.spouse
    json.partial! "v2/staff_agency/users/user_show_full.json.jbuilder", user: policy_user.user
  end
end

json.policy_coverages policy.coverages

json.primary_insurable do
  unless policy.primary_insurable.nil?
    json.partial! "v2/staff_agency/insurables/insurable_short_fields.json.jbuilder",
      insurable: policy.primary_insurable
    json.parent_community do
      if policy.primary_insurable.parent_community_for_all.present?
        json.partial! 'v2/staff_agency/insurables/insurable_short_fields.json.jbuilder',
          insurable: policy.primary_insurable.parent_community_for_all
      end
    end
    json.parent_building do
      if policy.primary_insurable.parent_building.present?
        json.partial! 'v2/staff_agency/insurables/insurable_short_fields.json.jbuilder',
        insurable: policy.primary_insurable.parent_building
      end
    end
  end
end

json.premium policy.premium

json.policy_type_title policy&.policy_type&.title

json.documents policy.documents do |document|
  json.id document.id
  json.filename document.filename
  json.url link_to_document(document)
  json.preview_url link_to_document_preview(document) if document.variable?
end
