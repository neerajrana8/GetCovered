json.extract! global_agency_permission, :agency_id
json.permissions do
  json.array! global_agency_permission.permissions.each do |key, value|
    json.key key
    json.category key.split('.').first
    json.title I18n.t("permissions.#{key}")
    json.value value
  end
end
