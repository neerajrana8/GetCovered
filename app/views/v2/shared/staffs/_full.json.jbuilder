json.partial! 'v2/shared/staffs/fields.json.jbuilder', staff: staff

json.profile_attributes do
  json.partial! 'v2/shared/profiles/fields.json.jbuilder', profile: staff.profile unless staff.profile.nil?
end
