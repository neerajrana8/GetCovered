json.array! @available_permissions.each do |key, default_value|
  json.key key
  json.title I18n.t("permissions.#{key}")
  category = key.split('.').first
  json.category category
  json.category_title I18n.t("permission_categories.#{category}")
  json.default_value default_value
end
