json.extract! global_agency_permission, :agency_id
json.permissions do
  json.array! GlobalAgencyPermission::AVAILABLE_PERMISSIONS.keys.each do |key|
    json.key key
    json.title I18n.t("permissions.#{key}")
    category = key.split('.').first
    json.category category
    json.category_title I18n.t("permission_categories.#{category}")
    json.value global_agency_permission.permissions[key]
  end
end

json.parent_global_agency_permission do
  if global_agency_permission.agency.parent_agency.present?
    json.partial! 'v2/shared/global_agency_permissions/full.json.jbuilder',
                  global_agency_permission: global_agency_permission.agency.parent_agency.global_agency_permission

  end
end
