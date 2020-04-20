require 'rails_helper'
include ActionController::RespondWith
ActiveJob::Base.queue_adapter = :test

describe 'Staff invitation spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @staff = create_agent_for @agency, profile: FactoryBot.create(:profile)
    login_staff @staff
    @auth_headers = get_auth_headers_from_login_response_headers(response)
    @staff_params = { staff: { 
      email: 'new_test@getcovered.com', 
      password: 'foobar', 
      organizable_id: @agency.id,
      organizable_type: "Agency",
      role: "agent"} 
    }
  end
  
  def create_staff(params)
    post '/v2/staff_agency/staffs', params: params, headers: @auth_headers
  end
  
  it 'should enable when invitation is accepted', perform_enqueued: true do
    allow(Rails.application.credentials).to receive(:uri).and_return({ test: { admin: 'localhost' } })
    
    expect { create_staff(@staff_params) }.to change { Staff.count }.by(1)
    new_staff = Staff.last
    put staff_invitation_path, params: {invitation_token: new_staff.invitation_token, password: 'foobar', password_confirmation: 'foobar'}
    result = JSON.parse response.body
    expect(new_staff.reload.enabled).to eq(true)
    expect(result["success"]).to eq(true)
  end
  
end