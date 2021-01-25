json.array! @available_permissions.each do |key, default_value|
  json.key key
  json.title I18n.t("permissions.#{key}")
  json.default_value default_value
end
