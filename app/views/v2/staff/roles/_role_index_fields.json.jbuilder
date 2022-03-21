json.extract! role, :id, :organizable_id, :organizable_type, :role, :primary, :active, :enabled, :created_at, :updated_at

if role.organizable_type == 'Account'
  json.account role.organizable&.title
  json.agency role.organizable&.agency&.title
end

if role.organizable_type == 'Agency'
  json.agency role.organizable&.title
  json.agency_owner role.organizable.staff_id === role.staff_id
end

json.permissions do
  if role.global_permission
    json.array! GlobalPermission::AVAILABLE_PERMISSIONS.keys.each do |key|
      json.key key
      json.title I18n.t("permissions.#{key}")
      category = key.split('.').first
      json.category category
      json.category_title I18n.t("permission_categories.#{category}")
      json.value role.global_permission.permissions.has_key?(key) ? role.global_permission.permissions[key] : false
    end
  end
end