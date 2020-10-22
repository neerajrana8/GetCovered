json.partial! 'v2/shared/staffs/fields.json.jbuilder', staff: staff

json.profile_attributes do
  json.partial! 'v2/shared/profiles/fields.json.jbuilder', profile: staff.profile unless staff.profile.nil?
end

json.organizable do
  if staff.organizable.present?
    json.organizable_type staff.organizable_type
    json.partial! "v2/shared/#{staff.organizable_type.downcase.pluralize}/short_fields.json.jbuilder",
                  staff.organizable_type.downcase.to_sym => staff.organizable
  end
end
