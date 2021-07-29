FactoryBot.define do
  factory :staff_permission do
    staff
    permissions { GlobalAgencyPermission::AVAILABLE_PERMISSIONS }
    global_agency_permission
  end
end
