json.array! staff_roles do
  staff_roles.each do |staff_role|
    json.extract! staff_role, :id, :role
    if staff_role.organizable_type == 'Account'
      json.account staff_role.organizable&.title
      json.agency  staff_role.organizable&.agency&.title
    end

    if staff_role.organizable_type == 'Agency'
      json.agency staff_role.organizable&.title
    end


    json.permissions do
      json.array! GlobalPermission::AVAILABLE_PERMISSIONS.keys.each do |key|
        json.key key
        json.title I18n.t("permissions.#{key}")
        category = key.split('.').first
        json.category category
        json.category_title I18n.t("permission_categories.#{category}")
        json.value staff_role.global_permission.permissions.has_key?(key) ? staff_role.global_permission.permissions[key] : false
      end
    end
  end
end