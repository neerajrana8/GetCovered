require 'rails_helper'
include ActionController::RespondWith

describe 'Leads API spec', type: :request do

  TEST_TAG = "test"

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

  private

  def create_lead_or_event(email, params)
    post '/v2/lead_events', params: params
    JSON.parse response.body
  end

  def new_event_params(email, identifier, last_visited_page, lead_step, lead_field_name, lead_step_value = Faker::Name.name)
    {
        "email": email,
        "identifier": "",
        "lead_event_attributes": {
            "tag": TEST_TAG,
            "latitude": Faker::Address.latitude,
            "longitude": Faker::Address.longitude,
            "agency_id":"",
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
        "lead_event_attributes": {
            "tag": TEST_TAG,
            "latitude":"",
            "longitude":"",
            "agency_id":"",
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
        "lead_event_attributes": {
            "tag": TEST_TAG,
            "latitude": Faker::Address.latitude,
            "longitude": Faker::Address.longitude,
            "agency_id":"",
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
    }
    }
  end


end
