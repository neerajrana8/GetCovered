require 'rails_helper'
include ActionController::RespondWith

# in test and test_container sending to klaviyo disabled, to make it work go to klaviyo_service and disable
# unless ["test", "test_container"].include?(ENV["RAILS_ENV"])
# but please don't push it with changes after
describe 'Leads API spec', type: :request do

  TEST_TAG = "test"

  before :all do
    @agency = FactoryBot.create(:agency)
    @branding_profile = FactoryBot.create(:branding_profile, profileable: @agency)
  end

  it 'should create new Lead from short params' do
    test_email = Faker::Internet.email

    result = create_lead_or_event(test_email, new_lead_short_params(test_email))

    expect(response.status).to eq(200)
    expect(result['identifier']).to_not eq(nil)
    expect(Lead.find_by(identifier: result['identifier']).email).to eq(test_email)
  end

  it 'should create new Lead from full params' do
    test_email = Faker::Internet.email

    result = create_lead_or_event(test_email, new_lead_full_params(test_email))

    expect(response.status).to eq(200)
    expect(result['identifier']).to_not eq(nil)

    test_lead = Lead.find_by(identifier: result['identifier'])
    expect(test_lead.email).to eq(test_email)
    expect(test_lead.lead_events.count).to eq(1)
    expect(test_lead.profile.present?).to eq(true)
    expect(test_lead.address.present?).to eq(true)
  end

  it 'should create new Lead Event' do
    test_email = Faker::Internet.email

    result = create_lead_or_event(test_email, new_lead_short_params(test_email))
    expect(response.status).to eq(200)

    sleep(5)
    lead_events = result['lead_events_count'] || 0

    result = create_lead_or_event(test_email,
                                  new_event_params(test_email, result["identifier"], 'Landing Page',
                                                   'fill last name', 'last_name'))

    test_lead = Lead.find_by(identifier: result['identifier'])
    expect(test_lead.lead_events.count).to eq(lead_events+2)
  end

  it 'should update Lead before create new Lead Event' do
    test_email = Faker::Internet.email

    result = create_lead_or_event(test_email, new_lead_short_params(test_email))
    expect(response.status).to eq(200)

    lead_events = result['lead_events_count'] || 0
    identifier  = result["identifier"]

    sleep(5)
    result = create_lead_or_event(test_email,
                                  new_event_params(test_email, identifier, 'Landing Page',
                                                   'fill last name', 'last_name'))

    result = create_lead_or_event(test_email, new_lead_full_params(test_email, identifier))

    test_lead = Lead.find_by(identifier: result['identifier'])
    expect(test_lead.lead_events.count).to eq(lead_events+3)
    expect(test_lead.profile.present?).to eq(true)
    expect(test_lead.address.present?).to eq(true)
  end

  context 'for StaffAgency roles' do
    before(:all) do
      @staff = FactoryBot.create(:staff, role: :super_admin)
      login_staff(@staff)
      @headers = get_auth_headers_from_login_response_headers(response)
      @test_email1 = Faker::Internet.email
      @test_email2 = Faker::Internet.email
      @lead_id1 = create_lead_or_event(@test_email1, new_lead_short_params(@test_email1))['id']
      @lead_id2 = create_lead_or_event(@test_email2,
                           new_lead_full_params(@test_email2))['id']
    end

    it 'should view lead index json' do
      response = index_admin_leads
      response_body = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(response_body.size).to eq(2)
    end

    it 'should view lead show json' do
      response1 = show_admin_leads(@lead_id1)
      response2 = show_admin_leads(@lead_id2)
      response_body1 = JSON.parse response1.body
      response_body2 = JSON.parse response2.body
      expect([response1, response2].map(&:status)).to eq([200, 200])
      expect(response_body1['email']).to eq(@test_email1)
      expect(response_body2['first_name'].present?).to eq(true)
    end

  end

  private

  def create_lead_or_event(email, params)
    post '/v2/lead_events', params: params
    JSON.parse response.body
  end

  def index_admin_leads
    get '/v2/staff_super_admin/leads', headers: @headers
    response
  end

  def show_admin_leads(id)
    get "/v2/staff_super_admin/leads/#{id}", headers: @headers
    response
  end

  def new_event_params(email, identifier, last_visited_page, lead_step, lead_field_name, lead_step_value = Faker::Name.name)
    {
        "email": email,
        "identifier": "",
        "agency_id": @agency.id,
        "lead_event_attributes": {
            "tag": TEST_TAG,
            "latitude": Faker::Address.latitude,
            "longitude": Faker::Address.longitude,
            "agency_id": @agency.id,
            "policy_type_id":"5",
            "data": { "last_visited_page": last_visited_page,
                      "action_type": "new",
                      "lead_step": lead_step,
                      "lead_field_name": lead_field_name,
                      "lead_step_value": lead_step_value
            }
        }
    }
  end

  def new_lead_short_params(email = Faker::Internet.email, identifier = "")
    {
        "email": email,
        "identifier": identifier,
        "agency_id": @agency.id,
        "lead_event_attributes": {
            "tag": TEST_TAG,
            "latitude":"",
            "longitude":"",
            "agency_id": @agency.id,
            "policy_type_id":"5",
            "data": {
                "last_visited_page": "Landing Page"
            }
       }
    }
  end

  def new_lead_full_params(email = Faker::Internet.email, identifier = "")
    {
        "email": email,
        "identifier": identifier,
        "agency_id": @agency.id,
        "lead_event_attributes": {
            "tag": TEST_TAG,
            "latitude": Faker::Address.latitude,
            "longitude": Faker::Address.longitude,
            "agency_id": @agency.id,
            "policy_type_id":"5",
            "data": { "last_visited_page": "Landing Page",
                      "action_type": "new",
                      "lead_step": "fill name",
                      "lead_field_name": "first_name",
                      "lead_step_value": Faker::Name.name
            }
    },
        "profile_attributes": {
        "birth_date": Faker::Date.birthday,
        "contact_phone": Faker::PhoneNumber.cell_phone,
        "first_name": Faker::Name.name,
        "gender": Faker::Gender.binary_type,
        "job_title": Faker::Job.title,
        "middle_name": Faker::Name.name,
        "last_name": Faker::Name.name,
        "salutation": Faker::Name.prefix
        },
        "address_attributes": {
        "city": Faker::Address.city,
        "country": Faker::Address.country,
        "state": Faker::Address.state,
        "street_name": Faker::Address.street_name,
        "street_two": Faker::Address.secondary_address,
        "zip_code": Faker::Address.zip_code
    },
        "tracking_url": {
            "campaign_content": "ccc",
            "campaign_medium": "mmm",
            "campaign_name": "nnn",
            "campaign_source": "sss",
            "campaign_term": "ttt",
            "landing_page": "rentguarantee"
        }
    }
  end
end
