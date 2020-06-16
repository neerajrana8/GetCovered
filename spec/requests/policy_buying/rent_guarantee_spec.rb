require 'rails_helper'
include ActionController::RespondWith

describe 'Policy buying' do
  describe 'Rent Guarantee Form' do
    it 'New user buys a policy' do
      carrier = Carrier.find(4)
      agency  = FactoryBot.create(:agency)
      carrier.agencies << agency
      billing_strategy = FactoryBot.create(:monthly_billing_strategy,
                                           agency: agency,
                                           carrier: carrier,
                                           policy_type_id: 5)

      # Create policy application
      post('/v2/policy-applications', params: correct_policy_application_params, headers: headers)
      expect(response.status).to eq(200)
      response_json = JSON.parse(response.body)
      policy_application_id = response_json['id']
      policy_application = PolicyApplication.find(policy_application_id)

      expect(policy_application).to be_present
      expect(policy_application.status).to eq('in_progress')

      # Update Policy
      put("/v2/policy-applications/#{policy_application_id}", params: update_policy_params, headers: headers)
      expect(response.status).to eq(200)
      response_json      = JSON.parse(response.body)
      policy_application = PolicyApplication.find(policy_application_id)
      expect(policy_application).to be_present
      expect(policy_application.status).to eq('quoted')
      policy_quote_id = response_json['quote']['id']
      primary_user_id = response_json['user']['id']
      ap response_json

      # Accept policy application
      post("/v2/policy-quotes/#{policy_quote_id}/accept", params: policy_quotes_accept_params(primary_user_id), headers: headers)
    end

    def headers
      { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
    end

    def correct_policy_application_params(new_user: true, co_tenant: false)
      {
        policy_application: {
          reference: nil,
          external_reference: nil,
          effective_date: DateTime.now + 2.days,
          expiration_date: DateTime.now + 1.year + 2.days,
          status: 'started',
          status_updated_on: nil,
          fields: {
            landlord: {
              email: nil,
              company: nil,
              last_name: nil,
              first_name: nil,
              phone_number: nil
            },
            employment: {
              primary_applicant: {
                address: {
                  city: nil,
                  state: nil,
                  county: nil,
                  country: nil,
                  zip_code: nil,
                  street_two: nil,
                  street_name: nil,
                  street_number: nil
                },
                company_name: nil,
                monthly_income: nil,
                employment_type: 'Full Time',
                job_description: 'Primary Applicants Job description',
                company_phone_number: nil
              },
              secondary_applicant: {
                address: {
                  city: nil,
                  state: nil,
                  county: nil,
                  country: nil,
                  zip_code: nil,
                  street_two: nil,
                  street_name: nil,
                  street_number: nil
                },
                company_name: nil,
                monthly_income: nil,
                employment_type: nil,
                job_description: nil,
                company_phone_number: nil
              }
            },
            monthly_rent: 2000,
            guarantee_option: 6
          },
          questions: [],
          carrier_id: 4,
          policy_type_id: 5,
          agency_id: 1,
          account_id: nil,
          billing_strategy_id: nil,
          policy_rates_attributes: [],
          policy_insurables_attributes: [],
          policy_users_attributes: [
            {
              primary: true,
              spouse: false,
              user_attributes: {
                email: 'applicant@email.com',
                profile_attributes: {
                  first_name: 'Applicant First Name',
                  last_name: 'Applicant Last Name',
                  contact_phone: '2122222222',
                  birth_date: DateTime.now - 20.years,
                  job_title: nil,
                  salutation: 'mr',
                  gender: 'female'
                },
                address_attributes: {
                  street_name: 'Test street',
                  street_two: '',
                  city: 'City 17',
                  state: 'DC',
                  zip_code: '12222',
                  country: 'United States'
                }
              }
            }
          ]
        }
      }.to_json
    end

    def update_policy_params
      {
        reference: nil,
        external_reference: nil,
        effective_date: DateTime.now + 2.days,
        expiration_date: DateTime.now + 1.year + 2.days,
        status: 'started',
        status_updated_on: nil,
        fields: {
          landlord: {
            email: 'landlord@email.com',
            company: 'Landlord Company',
            last_name: 'Landlord Last Name',
            first_name: 'Landlord First Name',
            phone_number: '1222222222'
          },
          employment: {
            primary_applicant: { 
              address: {
                city: 'Primary Applicant City',
                state: 'AS',
                county: nil,
                country: 'United States',
                zip_code: '12212',
                street_two: '',
                street_name: 'Primary Applicant Street',
                street_number: nil

              },
              company_name: 'Primary Applicants Company Name',
              monthly_income: nil,
              employment_type: 'Full Time',
              job_description: 'Primary Applicants Job description',
              company_phone_number: '1231222222' 
            },
            secondary_applicant: { 
              address: {
                city: '',
                state: '',
                county: nil,
                country: '',
                zip_code: '',
                street_two: '',
                street_name: '',
                street_number: nil
              },
              company_name: '',
              monthly_income: nil,
              employment_type: nil,
              job_description: nil,
              company_phone_number: '' 
            }
          },
          monthly_rent: 2000,
          guarantee_option: 6
        },
        questions: [],
        carrier_id: 4,
        policy_type_id: 5,
        agency_id: 1,
        account_id: nil,
        billing_strategy_id: nil,
        policy_rates_attributes: [],
        policy_insurables_attributes: [],
        policy_users_attributes: [
          { 
            primary: true,
            spouse: false,
            user_attributes: { 
              email: 'applicant@email.com',
              profile_attributes: {
                first_name: 'Applicant First Name',
                last_name: 'Applicant Last Name',
                contact_phone: '2122222222',
                birth_date: DateTime.now - 20.years,
                job_title: nil,
                salutation: 'mr',
                gender: 'female'
              },
              address_attributes: {
                street_name: 'Test street',
                street_two: '',
                city: 'City 17',
                state: 'DC',
                zip_code: '12222',
                country: 'United States'
              } 
            } 
          }
        ]
      }.to_json
    end

    def policy_quotes_accept_params(user_id)
      {
        user: {
          id: user_id,
          source: 'tok_visa'
        }
      }.to_json
    end

    def user_params; end

    def co_tenant_params; end
  end
end
