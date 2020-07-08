require 'rails_helper'
include ActionController::RespondWith

describe 'BrandingProfile API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @staff = create_agent_for @agency
    @super_admin = FactoryBot.create(:staff, role: 'super_admin')
  end
  
  context 'public api' do
    before :all do
      @new_agency = FactoryBot.create(:agency, title: 'New Whitelabel Agency')
      @agency_profile = FactoryBot.create(:branding_profile, title: "New agency", profileable: @new_agency, url: "new_agency.getcovered.com")
    end
    
    it 'should find correct profile with origin header' do
      get '/v2/branding-profile', headers: { 'Origin' => "https://new_agency.getcovered.com"}
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["id"]).to eq(@agency_profile.id)
      expect(result["url"]).to eq(@agency_profile.url)
    end
    
    it 'should find correct profile with path origin header' do
      get '/v2/branding-profile', headers: { 'Origin' => "https://new_agency.getcovered.com/vas?dfs=df"}
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["id"]).to eq(@agency_profile.id)
      expect(result["url"]).to eq(@agency_profile.url)
    end

    it 'should find correct profile with http header' do
      get '/v2/branding-profile', headers: { 'Origin' => "http://new_agency.getcovered.com/vas?dfs=df"}
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["id"]).to eq(@agency_profile.id)
      expect(result["url"]).to eq(@agency_profile.url)
    end
  end
  
  
  context 'for Agency role' do
    before :each do
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    it 'should create BrandingProfile' do
      post '/v2/staff_agency/branding-profiles', params: { branding_profile: correct_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(result["id"]).to_not eq(nil)
    end

    it 'should let create another BrandingProfile' do
      FactoryBot.create(:branding_profile, title: "New agency", profileable: @agency, url: "new_agency_test.getcovered.com")
      post '/v2/staff_agency/branding-profiles', params: { branding_profile: correct_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(201)
    end
    
    it 'should show BrandingProfile' do
      @profile = BrandingProfile.create(correct_params)
      get "/v2/staff_agency/branding-profiles/#{@profile.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["id"]).to_not eq(nil)
      expect(result["title"]).to eq(correct_params[:title])
      expect(result["profile_attributes"].count).to eq(1)
      expect(result["profile_attributes"].first['name']).to eq(correct_params[:branding_profile_attributes_attributes][0][:name])
    end
    
    it 'should update BrandingProfile' do
      @profile = BrandingProfile.create(correct_params)
      new_title = "A new title"
      style = { "colors"=>{"primary"=>"#fff"} }
      put "/v2/staff_agency/branding-profiles/#{@profile.id}", params: { branding_profile: {title: new_title, styles: style } }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["title"]).to eq(new_title)
      expect(result["styles"]).to eq(style)
    end

    it 'should destroy BrandingProfileAttribute' do
      attribute = BrandingProfile.create(correct_params).branding_profile_attributes.first
      delete "/v2/staff_agency/branding-profile-attributes/#{attribute.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
    end
    
  end
  
  context 'for SuperAdmin roles' do
    before :each do
      login_staff(@super_admin)
      @headers = get_auth_headers_from_login_response_headers(response)
    end
    
    it 'should create BrandingProfile' do
      post '/v2/staff_super_admin/branding-profiles', params: { branding_profile: correct_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(result["id"]).to_not eq(nil)
    end
    
    it 'should show BrandingProfile' do
      @profile = BrandingProfile.create(correct_params)
      get "/v2/staff_super_admin/branding-profiles/#{@profile.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["id"]).to_not eq(nil)
      expect(result["title"]).to eq(correct_params[:title])
      expect(result["profile_attributes"].count).to eq(1)
      expect(result["profile_attributes"].first['name']).to eq(correct_params[:branding_profile_attributes_attributes][0][:name])
    end
    
    it 'should update BrandingProfile' do
      @profile = BrandingProfile.create(correct_params)
      new_title = "A new title"
      style = { "colors"=>{"primary"=>"#fff"} }
      put "/v2/staff_super_admin/branding-profiles/#{@profile.id}", params: { branding_profile: {title: new_title, styles: style } }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["title"]).to eq(new_title)
      expect(result["styles"]).to eq(style)
    end
    
    it 'should destroy BrandingProfile' do
      @profile = BrandingProfile.create(correct_params)
      new_title = "A new title"
      style = { "colors"=>{"primary"=>"#fff"} }
      delete "/v2/staff_super_admin/branding-profiles/#{@profile.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["success"]).to eq(true)
    end

    it 'should destroy BrandingProfileAttribute' do
      attribute = BrandingProfile.create(correct_params).branding_profile_attributes.first
      delete "/v2/staff_super_admin/branding-profile-attributes/#{attribute.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
    end
    
  end
  
  def correct_params
    {
      subdomain: "",
      title: "GetCovered",
      profileable_id: @agency.id,
      profileable_type: "Agency",
      url: "getcovered.com",
      logo_url: "some_url.com",
      footer_logo_url: "some_url.com",
      branding_profile_attributes_attributes: [
        {
          name: "new_header_text",
          value: "This is agency's header text",
          attribute_type: "text"
        }
      ]
    }
  end
end 
