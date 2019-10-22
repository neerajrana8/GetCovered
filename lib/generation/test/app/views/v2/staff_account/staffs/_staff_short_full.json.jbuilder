json.partial! "v2/staff_account/staffs/staff_short_fields.json.jbuilder",
  staff: staff


json.profile_attributes do
  unless staff.profile.nil?
    json.partial! "v2/staff_account/profiles/profile_short_fields.json.jbuilder",
      profile: staff.profile
  end
end
