require 'rails_helper'
include ActionController::RespondWith

# in test and test_container sending to klaviyo disabled, to make it work go to klaviyo_service and disable
# unless ["test", "test_container"].include?(ENV["RAILS_ENV"])
# but please don't push it with changes after
describe 'Login Activities API spec', type: :request do

  context 'for Staff roles' do
    before(:all) do
      @staff = FactoryBot.create(:staff, role: :super_admin)
    end

    it 'should view login activities index json' do
      #login three times and save second headers
      3.times do
        @previous_headers = @headers if @headers
        login
      end
      #get active sessions by second headers should successfully respond
      response = index_staff_login_activities(@previous_headers)
      response_body = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(response_body.size).to eq(3)
      #close all active sessions witl last access headers should leave active only last headers
      response = get_close_all_session
      response_body = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(response_body).to eq({"message"=>"Sessions closed"})
      #should be only one active session
      response = index_staff_login_activities()
      response_body = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(response_body.size).to eq(1)
      #one active session should have client from last headers
      expect(LoginActivity.all.active.size).to eq(1)
      expect(LoginActivity.all.active.last.client).to eq(@headers['client'])
      #should not have access by inactive headers
      response = index_staff_login_activities(@previous_headers)
      expect(response.status).to eq(401)
    end

  end

  private

  def login
    login_staff(@staff)
    @headers = get_auth_headers_from_login_response_headers(response)
  end

  def index_staff_login_activities(headers = @headers)
    get '/v2/staff/login-activities', headers: headers
    response
  end

  def get_close_all_session
    get '/v2/staff/login-activities/close_all_sessions', headers: @headers
    response
  end

end
