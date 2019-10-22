json.partial! "v2/staff_agency/staffs/staff_short_fields.json.jbuilder",
  staff: staff


json.profile_attributes do
  unless staff.profile.nil?
    json.partial! "v2/staff_agency/profiles/profile_short_fields.json.jbuilder",
      profile: staff.profile
  end
end
