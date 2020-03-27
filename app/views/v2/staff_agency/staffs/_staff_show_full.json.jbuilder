json.partial! 'v2/staff_agency/staffs/staff_show_fields.json.jbuilder',
  staff: staff

json.profile_attributes do
  unless staff.profile.nil?
    json.partial! 'v2/staff_agency/profiles/profile_show_fields.json.jbuilder',
      profile: staff.profile
  end
end

json.communities do
  json.array! staff.assignments.communities do |community|
    json.partial! 'v2/shared/assignments/community.json.jbuilder', community: community
  end
end

if staff.organizable_type == 'Account'
  json.account staff&.organizable&.title
end

if staff.organizable_type == 'Agency'
  json.agency staff&.organizable&.title
end

