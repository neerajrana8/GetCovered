json.extract! staff_permission, :staff_id, :global_agency_permission_id
json.permissions do
  json.array! GlobalAgencyPermission::AVAILABLE_PERMISSIONS.keys.each do |key|
    json.key key
    json.title I18n.t("permissions.#{key}")
    category = key.split('.').first
    json.category category
    json.category_title I18n.t("permission_categories.#{category}")
    json.value staff_permission.permissions[key]
  end
end
