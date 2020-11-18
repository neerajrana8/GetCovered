json.partial! 'v2/shared/staffs/fields.json.jbuilder', staff: staff

json.profile_attributes do
  if staff.profile.present?
    json.partial! 'v2/shared/profiles/fields.json.jbuilder', profile: staff.profile
    json.full_name staff.profile.full_name
  end
end

json.organizable do
  if staff.organizable.present?
    json.organizable_type staff.organizable_type
    json.partial! "v2/shared/#{staff.organizable_type.downcase.pluralize}/short_fields.json.jbuilder",
                  staff.organizable_type.downcase.to_sym => staff.organizable
  end
end
