json.agency_id global_permission.ownerable_id if global_permission.ownerable_type === 'Agency'
json.account_id global_permission.ownerable_id if global_permission.ownerable_type === 'Account'

json.permissions do
  json.array! GlobalPermission::AVAILABLE_PERMISSIONS.keys.each do |key|
    json.key key
    json.title I18n.t("permissions.#{key}")
    category = key.split('.').first
    json.category category
    json.category_title I18n.t("permission_categories.#{category}")
    json.value global_permission.permissions.has_key?(key) ? global_permission.permissions[key] : false
  end
end

if follow
  if global_permission.ownerable_type === 'Agency'
    json.parent_global_agency_permission do
      if global_permission.ownerable.parent_agency.present?
        json.partial! 'v2/shared/global_permissions/full.json.jbuilder',
                      global_permission: global_permission.ownerable.parent_agency.global_permission,
                      follow: false

      end
    end
  end
end