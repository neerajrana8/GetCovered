require 'rails_helper'

RSpec.describe GlobalPermission, type: :model do
  it 'updates permissions in subagencies' do
    agency = FactoryBot.create(:agency)
    # agency.run_callbacks :create
    sub_agency = FactoryBot.create(:sub_agency, agency: agency)
    # sub_agency.run_callbacks :create
    agency.agencies << sub_agency
    agency.save!
    # agency.run_callbacks :update

    global_permission = agency.global_permission
    permission = global_permission.permissions.keys.first
    new_permissions = agency.global_permission.permissions
    new_permissions[permission] = false
    global_permission.update!(permissions: new_permissions)
    # global_permission.run_callbacks :save

    expect(global_permission).to be_valid

    expect(agency.agencies.last.global_permission.permissions[permission]).to be false
  end
end
