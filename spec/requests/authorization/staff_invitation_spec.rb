require 'rails_helper'
require 'nokogiri'
include ActionController::RespondWith
ActiveJob::Base.queue_adapter = :test

describe 'Staff invitation spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @staff = create_agent_for @agency, profile: FactoryBot.create(:profile)
    login_staff @staff
    @auth_headers = get_auth_headers_from_login_response_headers(response)
    @staff_params = { staff: {
      email: 'new_test_invitation@getcovered.com',
      password: 'foobar',
      uid: 'new_test_invitation@getcovered.com',
      provider: 'email',
      organizable_id: @agency.id,
      organizable_type: "Agency",
      role: "agent"}
    }
  end

  def create_staff(params)
    post '/v2/staff_agency/staffs', params: params, headers: @auth_headers
  end

  it 'should enable when invitation is accepted', perform_enqueued: true do
    expect { create_staff(@staff_params) }.to change { ::Staff.count }.by(1)
    last_mail = Nokogiri::HTML(ActionMailer::Base.deliveries.last.html_part.body.decoded)
    url = last_mail.css('a').first["href"]
    token = url.partition("localhost:4100/auth/accept-invitation/").last

    new_staff = ::Staff.last
    put staff_invitation_path, params: { invitation_token: token, password: 'foobar', password_confirmation: 'foobar' }

    result = JSON.parse response.body
    expect(new_staff.reload.enabled).to eq(true)
    expect(new_staff.owner).to eq(false)
    expect(result["success"]).to eq(["User updated."])
  end
end
