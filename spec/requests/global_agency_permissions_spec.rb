require 'rails_helper'
include ActionController::RespondWith

describe 'Global Agency Permission spec', type: :request do
  let!(:super_admin) { FactoryBot.create(:staff, role: 'super_admin') }

  before :each do
    login_staff(super_admin)
    @headers = get_auth_headers_from_login_response_headers(response)
  end

  it 'disables permission for an agency staff' do
    pending('To delete')
    agency = FactoryBot.create(:agency)
    staff = FactoryBot.create(:staff, role: 'agent', organizable: agency)
    permission = agency.global_agency_permission.permissions.keys.first

    new_agency_permissions = agency.global_agency_permission.permissions
    new_agency_permissions[permission] = false

    put "/v2/staff_super_admin/agencies/#{agency.id}", params: { agency: params(new_agency_permissions) }, headers: @headers

    expect(response.status).to eq(200)

    staff.reload

    expect(staff.staff_permission.permissions[permission]).to be false
  end

  it 'disables permission for a subagency' do
    pending('To delete')
    agency = FactoryBot.create(:agency)
    sub_agency = FactoryBot.create(:agency, agency: agency)
    permission = agency.global_agency_permission.permissions.keys.first

    new_agency_permissions = agency.global_agency_permission.permissions
    new_agency_permissions[permission] = false

    put "/v2/staff_super_admin/agencies/#{agency.id}", params: { agency: params(new_agency_permissions) }, headers: @headers

    expect(response.status).to eq(200)

    sub_agency.reload

    expect(sub_agency.global_agency_permission.permissions[permission]).to be false
  end

  private
  
  def params(permissions)
    {
      global_agency_permission_attributes: {
        permissions: permissions
      }
    }
  end
  
  
end
