require 'rails_helper'
include ActionController::RespondWith

describe 'Staff Permission spec', type: :request do
  let!(:agency_owner) { FactoryBot.create(:staff, role: 'agent') }

  before :each do
    login_staff(agency_owner)
    @headers = get_auth_headers_from_login_response_headers(response)
  end

  it 'raise error permission for an agency staff' do
    agency = FactoryBot.create(:agency, staff_id: agency_owner.id)
    staff = FactoryBot.create(:staff, role: 'agent', organizable: agency)
    permission = agency.global_permission.permissions.keys.first

    all_enabled_permissions = agency.global_permission.permissions.clone
    new_agency_permissions = agency.global_permission.permissions
    new_agency_permissions[permission] = false
    agency.global_permission.update(permissions: new_agency_permissions)

    put "/v2/staff_agency/staffs/#{staff.id}", params: { staff: params(all_enabled_permissions) }, headers: @headers

    expect(response.status).to eq(422)
    result = JSON.parse response.body
    expect(result['error']).to eq('staff_update_error')
  end

  private
  
  def params(permissions)
    {
      staff_permission_attributes: {
        permissions: permissions
      }
    }
  end
end
