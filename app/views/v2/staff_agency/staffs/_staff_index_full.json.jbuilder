json.partial! "v2/staff_agency/staffs/staff_index_fields.json.jbuilder",
  staff: staff


json.profile_attributes do
  unless staff.profile.nil?
    json.partial! "v2/staff_agency/profiles/profile_short_fields.json.jbuilder",
      profile: staff.profile
  end
end

json.organizable_title staff.organizable&.title

json.staff_roles do
  json.partial! 'v2/shared/staff_roles/full.json.jbuilder', staff_roles: staff.staff_roles
end
