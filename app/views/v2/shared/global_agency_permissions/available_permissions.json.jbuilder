json.array! @available_permissions.each do |available_permission|
  json.key available_permission[:key]
  json.title I18n.t("permissions.#{available_permission[:key]}")
  json.default_value available_permission[:default_value]
end
