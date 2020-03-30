require 'rails_helper'
include ActionController::RespondWith

describe 'BrandingProfile API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @staff = create_agent_for @agency
  end
  
  before :each do
    login_staff(@staff)
    @headers = get_auth_headers_from_login_response_headers(response)
  end
  
  context 'for Admin roles' do
    it 'should create BrandingProfile' do
      post '/v2/staff_agency/branding-profiles', params: { branding_profile: correct_params }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(201)
      expect(result["id"]).to_not eq(nil)
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
    
  end
  
  def correct_params
    {
      subdomain: "os",
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
