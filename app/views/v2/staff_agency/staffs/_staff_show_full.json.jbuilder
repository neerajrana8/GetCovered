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
  json.agency  staff&.organizable&.agency&.title
end

if staff.organizable_type == 'Agency'
  json.agency staff&.organizable&.title
end

json.staff_permission do
  if @staff.staff_permission.present?
    json.partial! 'v2/shared/staff_permissions/full.json.jbuilder', staff_permission: staff.staff_permission
  end
end

json.staff_roles do
  if staff.staff_roles.present?
    if @organizable_type
      roles = staff.staff_roles.where(organizable_type: @organizable_type)
    else
      roles = staff.staff_roles
    end
    json.partial! 'v2/shared/staff_roles/full.json.jbuilder', staff_roles: roles
  end
end