module PolicyApplicationGroups
  class SourceXlsxParser < ActiveInteraction::Base
    object :xlsx_file, class: IO

    def execute
      xlsx = Roo::Spreadsheet.open(xlsx_file)
      sheet = xlsx.sheet(0).parse(headers: true)
      result = []
      sheet[1..-1].each do |row|
        if row_empty?(row)
          break
        else
          result << grouped_data(row)
        end
      end
      result
    end

    private

    def grouped_data(row)
      {
        policy_application: {
          fields: {
            "landlord" =>
              {
                "email" => row["Landlord Email Address"],
                "company" => nil,
                "last_name" => row["Landlord Contact name-Last"],
                "first_name" => row["Landlord Contact name-First"],
                "phone_number" => row["Landlord Phone number"]
              },
            "employment" => employment(row),
            "monthly_rent" => row["Monthly Rent ($)-Dollars"],
            "guarantee_option" => row["3, 6, or 12 Months Option Rent Guarantee"]
          }
        },
        policy_users: policy_users(row)
      }
    end

    def employment(row)
      employment_hash =
        {
          "primary_applicant" =>
            {
              "address" =>
                {
                  "city" => row["Applicant's Employer's Address-City"],
                  "state" => row["Applicant's Employer's Address-State"],
                  "county" => nil,
                  "country" => row["Applicant's Employer's Address-Country"],
                  "zip_code" => row["Applicant's Employer's Address-Postal / Zip Code"],
                  "street_two" => row["Applicant's Employer's Address-Street Address Line 2"],
                  "street_name" => row["Applicant's Employer's Address-Street Address"],
                  "street_number" => nil
                },
              "company_name" => row["Applicant's Employer's Name"],
              "monthly_income" => row["Applicant's Monthly Income"],
              "employment_type" => row["Applicant's Employment type"],
              "job_description" => row["Applicant's Employment Description"],
              "company_phone_number" => row["Applicant's Employer's Phone number"]
            }
        }
      if row["Co-Tenant Employer's Name"].present?
        employment_hash['secondary_applicant'] =
          {
            "address" =>
              {
                "city" => row["Co-Tenant's Employer's Address-City"],
                "state" => row["Co-Tenant's Employer's Address-State"],
                "county" => nil,
                "country" => row["Co-Tenant's Employer's Address-Country"],
                "zip_code" => row["Co-Tenant's Employer's Address-Postal / Zip Code"],
                "street_two" => row["Co-Tenant's Employer's Address-Street Address2"],
                "street_name" => row["Co-Tenant's Employer's Address-Street Address"],
                "street_number" => nil
              },
            "company_name" => row["Co-Tenant Employer's Name"],
            "monthly_income" => row["Co-Tenant Monthly Income"],
            "employment_type" => row["Co-Tenant Employment"],
            "job_description" => row["Co-Tenant Employment Description"],
            "company_phone_number" => row["Co-Tenant's Employer's Phone number"]
          }
      end
      employment_hash
    end

    def policy_users(row)
      policy_users_params = [
        {
          primary: true,
          user_attributes: {
            email: row["Applicant's Email address"],
            profile_attributes: {
              first_name: row["Applicant's Name-First"],
              last_name: row["Applicant's Name-Last"],
              job_title: row["Applicant's Employment Description"],
              contact_phone: row["Phone number"],
              birth_date: row["Applicant's Date of birth"],
              gender: row["Gender"],
              salutation: row['Salutation']
            }
          }
        }
      ]
      if row["Co-Tenant Email address2"].present?
        policy_users_params << [
          {
            user_attributes: {
              email: row["Co-Tenant Email address2"],
              profile_attributes: {
                first_name: row["Co-Tenant Name-First"],
                last_name: row["Co-Tenant Name-Last"],
                job_title: row["Co-Tenant Employment Description"],
                contact_phone: row["Co-Tenant Phone number"],
                birth_date: row["Co-Tenant Date of birth"],
                gender: row["Gender2"],
                salutation: row["Co-Tenant Salutation"],
              }
            }
          }
        ]
      end
      policy_users_params
    end

    def row_empty?(row)
      # Excepts always calculated field and strange ending
      row.except("Program Fee ($)-Dollars").values[0..53].compact.blank?
    end
  end
end
