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
require 'rails_helper'

describe 'Staff Permission spec', type: :request do
  #let!(:agency_owner) { FactoryBot.create(:staff, role: 'agent') }

  it 'permissions created during the staffs creation' do
    agency = FactoryBot.create(:agency)
    staff =  create_agent_for agency, profile: FactoryBot.create(:profile)

    expect(staff).to be_valid
    expect(staff.staff_roles.where(organizable: agency).take.global_permission.permissions).to eq(agency.global_permission.permissions)
  end
end
