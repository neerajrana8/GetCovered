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
    post '/v2/staff_agency/agencies', params: { agency: params }, headers: @auth_headers
  end

  it 'should create new agency with first staff as owner', perform_enqueued: true do
    expect { create_agency(agency_params) }.to change { Agency.count }.by(1)
    expect(Agency.last.agency).to eq(@agency)
    expect { create_staff(staff_params(Agency.last)) }.to change { ::Staff.count }.by(1)

    expect(::Staff.last.owner).to eq(true)
  end

  def agency_params
    {
      title: 'New test agency',
      tos_accepted: true,
      whitelabel: false,
      global_permission_attributes: {
        permissions: GlobalPermission::AVAILABLE_PERMISSIONS
      }
    }
  end

  def staff_params(agency)
    {
      staff: {
        email: 'new_test@getcovered.com',
        organizable_id: agency.id,
        organizable_type: 'Agency',
        role: 'agent'
      }
    }
  end
end

describe 'Agency api spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    admin = create_super_admin
    login_staff admin
    @auth_headers = get_auth_headers_from_login_response_headers(response)
  end

  def create_agency(params)
    post '/v2/staff_super_admin/agencies', params: { agency: params }, headers: @auth_headers
  end

  def get_agencies
    get '/v2/staff_super_admin/agencies', headers: @auth_headers
  end

  def get_sub_agencies(params)
    get '/v2/staff_super_admin/agencies', params: { filter: params, with_subagencies: true }, headers: @auth_headers
  end

  def create_sub_agency(params)
    post '/v2/staff_super_admin/agencies', params: { agency: params }, headers: @auth_headers
  end

  def get_sub_agencies_short
    get "/v2/staff_super_admin/agencies/sub_agencies?agency_id=#{@agency.id}", headers: @auth_headers
  end

  def get_agencies_short
    get '/v2/staff_super_admin/agencies/sub_agencies', headers: @auth_headers
  end

  def update_agency(params)
    put "/v2/staff_super_admin/agencies/#{@agency.id}", params: { agency: params }, headers: @auth_headers
  end

  it 'should create new subagency', perform_enqueued: true do
    sub_agency = create_agency(sub_agency_params)

    expect(@agency.agencies.count).to eq(1)
  end

  it 'should get only agencies', perform_enqueued: true do
    get_agencies
    agencies = JSON.parse(response.body)

    expect(agencies.map { |el| el['agency_id'] }.uniq).to eq([nil])
  end

  it 'should get only sub-agencies', perform_enqueued: true do
    create_sub_agency(sub_agency_params)
    get_sub_agencies(get_sub_agency_params)
    sub_agencies = JSON.parse(response.body)
    expect(sub_agencies.map { |el| el['agency_id'] }.uniq).to eq([@agency.id])
  end

  it 'should throw error when parent agency not exist', perform_enqueued: true do
    create_sub_agency(sub_agency_params(rand(1000..1111)))
    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)['payload']).to eq(['Agency Parent id incorrect'])
  end

  it 'should throw error when agency tried to update to sub-agency', perform_enqueued: true do
    params = @agency.as_json
    params['agency_id'] = @agency.id
    update_agency(update_agency_params)
    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)['agency']).to eq(["Agency can't be updated to sub-agency"])
  end

  it 'should get only sub-agencies in short response', perform_enqueued: true do
    create_sub_agency(sub_agency_params)
    get_sub_agencies_short
    sub_agencies = JSON.parse(response.body)
    expect(sub_agencies.map { |el| el['agency_id'] }.uniq).to eq([@agency.id])
    expect(sub_agencies.first.keys).to eq(%w[id title enabled agency_id])
  end

  it 'should get only agencies in short response', perform_enqueued: true do
    create_sub_agency(sub_agency_params)
    get_agencies_short
    agencies = JSON.parse(response.body)
    expect(agencies.map { |el| el['agency_id'] }.uniq).to eq([nil])
    # expect(agencies.first.keys).to eq(["id", "title", "agency_id"])
  end

  def agency_params
    {
      title: 'New test agency',
      tos_accepted: true,
      whitelabel: false,
      global_permission_attributes: {
        permissions: GlobalPermission::AVAILABLE_PERMISSIONS
      }
    }
  end

  def sub_agency_params(agency_id = @agency.id)
    {
      title: 'New test subagency',
      tos_accepted: true,
      whitelabel: false,
      agency_id: agency_id,
      global_permission_attributes: {
        permissions: GlobalPermission::AVAILABLE_PERMISSIONS
      }
    }
  end

  def get_sub_agency_params
    {
      agency_id: @agency.id
    }
  end

  def update_agency_params
    { title: 'New Test Agency',
      agency_id: @agency.id,
      enabled: 'true',
      whitelabel: 'true',
      global_permission_attributes: {
        permissions: GlobalPermission::AVAILABLE_PERMISSIONS
      },
      contact_info: { "contact_email": '', "contact_phone": '', "contact_fax": '' } }
  end
end
