require 'rails_helper'
require 'nokogiri'
include ActionController::RespondWith
ActiveJob::Base.queue_adapter = :test

describe 'Agency invitation spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @staff = create_agent_for @agency, profile: FactoryBot.create(:profile)
    login_staff @staff
    @auth_headers = get_auth_headers_from_login_response_headers(response)
  end
  
  def create_staff(params)
    post '/v2/staff_agency/staffs', params: params, headers: @auth_headers
  end
  
  def create_agency(params)
    post '/v2/staff_agency/agencies', params: {agency: params}, headers: @auth_headers
  end
  
  it 'should create new subagency with first staff as owner', perform_enqueued: true do
    
    expect { create_agency(agency_params) }.to change { Agency.count }.by(1)
    expect(Agency.last.agency).to eq(@agency)
    
    expect { create_staff(staff_params(Agency.last)) }.to change { Staff.count }.by(1)
    
    expect(Staff.last.owner).to eq(true)
  end
  
  def agency_params
    {
      title: "New test agency",
      tos_accepted: true, 
      whitelabel: false
    }
  end
  def staff_params(agency)
    {
      staff: { 
        email: 'new_test@getcovered.com', 
        organizable_id: agency.id,
        organizable_type: "Agency",
        role: "agent"
      }
    }
  end
  
  
end
