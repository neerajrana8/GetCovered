# == Schema Information
#
# Table name: staff_permissions
#
#  id                          :bigint           not null, primary key
#  permissions                 :jsonb
#  global_agency_permission_id :bigint
#  staff_id                    :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
FactoryBot.define do
  factory :staff_permission do
    staff
    permissions { GlobalAgencyPermission::AVAILABLE_PERMISSIONS }
    global_agency_permission
  end
end
