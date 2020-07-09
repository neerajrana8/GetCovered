module Helpers
  class RentGuaranteeFormParamsGenerator < ActiveInteraction::Base
    string :applicant_email, default: 'applicant@email.com'
    integer :agency_id
    hash :co_tenant, default: nil do
      string :email, default: 'co-tenant@email.com'
    end

    def execute
      {
        create_policy_application: create_policy_application,
        update_policy_application: update_policy_application
      }
    end

    private

    def create_policy_application
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
          agency_id: agency_id,
          account_id: nil,
          billing_strategy_id: nil,
          policy_rates_attributes: [],
          policy_insurables_attributes: [],
          policy_users_attributes: policy_users_attributes
        }
      }.to_json
    end

    def update_policy_application
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
        agency_id: agency_id,
        account_id: nil,
        billing_strategy_id: nil,
        policy_rates_attributes: [],
        policy_insurables_attributes: [],
        policy_users_attributes: policy_users_attributes
      }.to_json
    end

    def policy_users_attributes
      result = [primary_user_attributes]
      result << co_tenant_attributes if co_tenant.present?
      result
    end

    def primary_user_attributes
      {
        primary: true,
        spouse: false,
        user_attributes: {
          email: applicant_email,
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
    end

    def co_tenant_attributes
      {
        primary: false,
        spouse: false,
        user_attributes: {
          email: co_tenant[:email],
          profile_attributes: {
            first_name: 'CoTenant First Name',
            last_name: 'CoTenant Last Name',
            contact_phone: '2122222222',
            birth_date: DateTime.now - 20.years,
            job_title: nil,
            salutation: 'mr',
            gender: 'female'
          },
          address_attributes: {
            street_name: 'Test co-tenant street',
            street_number: '13',
            street_two: '12',
            city: 'City 17',
            state: 'DC',
            zip_code: '12222',
            country: 'United States'
          }
        }
      }
    end
  end
end
