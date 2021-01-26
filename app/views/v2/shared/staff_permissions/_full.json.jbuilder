json.extract! staff_permission, :staff_id, :global_agency_permission_id
json.permissions do
  json.array! staff_permission.permissions.each do |key, value|
    json.key key
    json.title I18n.t("permissions.#{key}")
    category = key.split('.').first
    json.category category
    json.category_title I18n.t("permission_categories.#{category}")
    json.value value
  end
end
