json.extract! staff_permission, :staff_id, :global_agency_permission_id
json.permissions do
  json.array! staff_permission.permissions.each do |key, value|
    json.key key
    json.category key.split('.').first
    json.title I18n.t("permissions.#{key}")
    json.value value
  end
end
