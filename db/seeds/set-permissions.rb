# Get Covered Insurable Seed Setup File

Agency.main_agencies.each do |agency|
  unless agency.global_agency_permission.present?
    GlobalAgencyPermission.create(agency: agency, permissions: GlobalAgencyPermission::AVAILABLE_PERMISSIONS)
  end
end

Agency.sub_agencies.each do |agency|
  unless agency.global_agency_permission.present?
    GlobalAgencyPermission.create(agency: agency, permissions: agency.agency.global_agency_permission.permissions)
  end
end

Staff.agent.each do |agent|
  unless agent
    StaffPermission.create(staff: agent) unless agent.staff_permission.present?
  end
end
