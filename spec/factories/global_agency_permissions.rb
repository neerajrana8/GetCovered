# == Schema Information
#
# Table name: global_agency_permissions
#
#  id          :bigint           not null, primary key
#  permissions :jsonb
#  agency_id   :bigint
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :global_agency_permission do
    permissions { GlobalAgencyPermission::AVAILABLE_PERMISSIONS }
    agency
  end
end
