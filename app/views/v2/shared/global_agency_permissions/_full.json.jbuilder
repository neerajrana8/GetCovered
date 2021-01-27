json.extract! global_agency_permission, :agency_id
json.permissions do
  json.array! global_agency_permission.permissions.each do |key, value|
    json.key key
    json.title I18n.t("permissions.#{key}")
    category = key.split('.').first
    json.category category
    json.category_title I18n.t("permission_categories.#{category}")
    json.value value
  end
end

json.parent_global_agency_permission do
  if global_agency_permission.agency.agency.present?
    json.partial! 'v2/shared/global_agency_permissions/full.json.jbuilder',
                  global_agency_permission: global_agency_permission.agency.agency.global_agency_permission

  end
end
