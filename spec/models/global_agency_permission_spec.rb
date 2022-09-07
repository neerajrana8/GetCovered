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
require 'rails_helper'

RSpec.describe GlobalAgencyPermission, type: :model do
  it 'updates permissions in subagencies' do
    agency = FactoryBot.create(:agency)
    sub_agency = FactoryBot.create(:agency, agency: agency)

    global_agency_permission = agency.global_agency_permission
    permission = global_agency_permission.permissions.keys.first
    new_permissions = agency.global_agency_permission.permissions
    new_permissions[permission] = false
    global_agency_permission.update(permissions: new_permissions)

    expect(global_agency_permission).to be_valid

    sub_agency.reload

    expect(sub_agency.global_agency_permission.permissions[permission]).to be false
  end
end
