FactoryBot.define do
  factory :global_agency_permission do
    permissions { GlobalAgencyPermission::AVAILABLE_PERMISSIONS }
    agency
  end
end
