require 'rails_helper'
include ActionController::RespondWith

describe 'Policy buying' do
  describe 'Rent Guarantee Form' do
    it 'New user buys a policy' do
      post('/v2/policy-applications', params: correct_policy_application_params)

      expect(response.status).to eq(200)
    end

    def correct_policy_application_params(new_user: true, co_tenant: false)
      {
        policy_application: {
          "reference": nil,
          "external_reference": nil,
          "effective_date": '2020-06-17',
          "expiration_date": '2021-06-17',
          "status": 'started',
          "status_updated_on": nil,
          "fields": {
            "landlord": {
              "email": nil,
              "company": nil,
              "last_name": nil,
              "first_name": nil,
              "phone_number": nil
            },
            "employment": {
              "primary_applicant": {
                "address": {
                  "city": nil,
                  "state": nil,
                  "county": nil,
                  "country": nil,
                  "zip_code": nil,
                  "street_two": nil,
                  "street_name": nil,
                  "street_number": nil
                },
                "company_name": nil,
                "monthly_income": nil,
                "employment_type": 'Full Time',
                "job_description": 'weeaas',
                "company_phone_number": nil
              },
              "secondary_applicant": {
                "address": {
                  "city": nil,
                  "state": nil,
                  "county": nil,
                  "country": nil,
                  "zip_code": nil,
                  "street_two": nil,
                  "street_name": nil,
                  "street_number": nil
                },
                "company_name": nil,
                "monthly_income": nil,
                "employment_type": nil,
                "job_description": nil,
                "company_phone_number": nil
              }
            },
            "monthly_rent": 2222,
            "guarantee_option": 6
          },
          "questions": [],
          "carrier_id": 4,
          "policy_type_id": 5,
          "agency_id": 1,
          "account_id": nil,
          "billing_strategy_id": nil,
          "policy_rates_attributes": [],
          "policy_insurables_attributes": [],
          "policy_users_attributes": [
            {
              "primary": true,
              "spouse": false,
              "user_attributes": {
                "email": 'cwwqw@gmail.com',
                "profile_attributes": {
                  "first_name": 'Cw',
                  "last_name": 'S',
                  "contact_phone": '1222222222',
                  "birth_date": '2002-05-16',
                  "job_title": nil,
                  "salutation": 'mr',
                  "gender": 'male'
                },
                "address_attributes": {
                  "street_name": 'Csd',
                  "street_two": '',
                  "city": 'SD',
                  "state": 'AZ',
                  "zip_code": '12222',
                  "country": 'United States'
                }
              }
            }
          ] 
        }
      }
    end

    def user_params; end

    def co_tenant_params; end
  end
end
