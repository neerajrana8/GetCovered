require 'rails_helper'
include ActionController::RespondWith

describe 'Page API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @branding_profile = FactoryBot.create(:branding_profile, profileable: @agency)
    @staff = create_agent_for @agency
  end
  
  before :each do
    login_staff(@staff)
    @headers = get_auth_headers_from_login_response_headers(response)
  end
  
  context 'for Admin roles' do
    it 'should create Page' do
      post '/v2/staff_agency/pages', params: { page: correct_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(result["id"]).to_not eq(nil)
    end
    
    it 'should show Page' do
      @page = Page.create(correct_params)
      get "/v2/staff_agency/pages/#{@page.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["id"]).to_not eq(nil)
      expect(result["content"]).to eq(correct_params[:content])
      expect(result["title"]).to eq(correct_params[:title])
    end

    it 'should show a list of Pages' do
      page = Page.create(correct_params)
      second_page = Page.create(correct_params)
      get "/v2/staff_agency/pages", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result.count).to eq(2)
    end


    it 'should update Page' do
      @page = Page.create(correct_params)
      new_title = "A new title"
      put "/v2/staff_agency/pages/#{@page.id}", params: { page: {title: new_title } }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["title"]).to eq(new_title)
    end

    it 'should destroy Page' do
      @page = Page.create(correct_params)
      delete "/v2/staff_agency/pages/#{@page.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["success"]).to eq(true)
    end

    
  end
  
  def correct_params
    {
      title: "GetCovered",
      content: "This is page content",
      agency_id: @agency.id,
      branding_profile_id: @branding_profile.id
    }
  end
end 
