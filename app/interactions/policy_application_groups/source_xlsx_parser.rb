module PolicyApplicationGroups
  class SourceXlsxParser < ActiveInteraction::Base
    ALWAYS_PRESENT_ROWS = ["Applicant's Date of birth", 'Monthly Rent ($)-Dollars', 'Address-State'].freeze
    object :xlsx_file, class: IO

    def execute
      xlsx = Roo::Spreadsheet.open(xlsx_file)
      sheet = xlsx.sheet(0).parse(headers: true)
      result = []
      sheet[1..-1].each do |row|
        if row_empty?(row)
          break
        else
          result << grouped_data(row) if row_valid?(row)
        end
      end
      result
    end

    private

    def row_valid?(row)
      empty_necessary_rows = ALWAYS_PRESENT_ROWS.select { |column| row[column].blank? }
      if empty_necessary_rows.any?
        errors[:bad_rows] << {
          message: "Next columns columns with applicant's email #{row["Applicant's Email address"]} should be present: #{empty_necessary_rows}",
          column: row["Applicant's Email address"]
        }
        return false
      end

      state_codes = Address::US_STATE_CODES.keys.map(&:to_s)

      unless state_codes.include?(row['Address-State'])
        errors[:bad_rows] << {
          message: "Address-State for #{row["Applicant's Email address"]} should be in the next list: #{state_codes.join(', ')}",
          column: row["Applicant's Email address"]
        }
        return false
      end

      unless valid_number?(row['Monthly Rent ($)-Dollars'])
        errors[:bad_rows] << {
          message: "Column with applicant's email: #{row["Applicant's Email address"]} has wrong Monthly Rent ($)-Dollars",
          column: row["Applicant's Email address"]
        }
        return false
      end

      if row["Applicant's Date of birth"] > 18.years.ago
        errors[:bad_rows] << {
          message: "Column with applicant's email: #{row["Applicant's Email address"]} has wrong Applicant's Date of birth",
          column: row["Applicant's Email address"]
        }
        return false
      end

      if row['Co-Tenant Email address2'].present? && (row['Co-Tenant Date of birth'].blank? || row['Co-Tenant Date of birth'] > 18.years.ago)
        errors[:bad_rows] << {
          message: "Column with co tenant's email: #{row['Co-Tenant Email address2']} has wrong Co-Tenant Date of birth",
          column: row['Co-Tenant Email address2']
        }
        return false
      end

      if row['Co-Tenant Email address2'] == row["Applicant's Email address"]
        errors[:bad_rows] << {
          message: "A co-tenant can't have the same email with an applicant",
          column: row["Applicant's Email address"]
        }
        return false
      end

      true
    end

    def valid_number?(string)
      Float(string) != nil rescue false
    end

    def grouped_data(row)
      {
        policy_application: {
          fields: {
            'landlord' =>
              {
                'email' => row['Landlord Email Address'],
                'company' => row['Landlord - Company Name (if applicable)'],
                'last_name' => row['Landlord Contact name-Last'],
                'first_name' => row['Landlord Contact name-First'],
                'phone_number' => row['Landlord Phone number']
              },
            'monthly_income' => row["Applicant's Monthly Income"],
            'employment' => employment(row),
            'monthly_rent' => row['Monthly Rent ($)-Dollars']&.to_i,
            'guarantee_option' => guarantee_option(row['3, 6, or 12 Months Option Rent Guarantee']),
            'tos' => row["Terms of Service-I agree to the terms and conditions of the Rent Guarantee Agreement and the Rent Guarantee Summary"]
          }
        },
        policy_users: policy_users(row)
      }
    end

    def guarantee_option(cell_value)
      case cell_value
      when '3 Months Option'
        '3 Month'
      when '6 Months Option'
        '6 Month'
      when '12 Months Option'
        '12 Month'
      else
        cell_value
      end
    end

    def employment(row)
      employment_hash =
        {
          'primary_applicant' =>
            {
              'address' =>
                {
                  'city' => row["Applicant's Employer's Address-City"],
                  'state' => row["Applicant's Employer's Address-State"],
                  'county' => nil,
                  'country' => row["Applicant's Employer's Address-Country"],
                  'zip_code' => row["Applicant's Employer's Address-Postal / Zip Code"],
                  'street_two' => row["Applicant's Employer's Address-Street Address Line 2"],
                  'street_name' => row["Applicant's Employer's Address-Street Address"],
                  'street_number' => nil
                },
              'company_name' => row["Applicant's Employer's Name"],
              'employment_type' => row["Applicant's Employment type"],
              'job_description' => row["Applicant's Employment Description"],
              'company_phone_number' => row["Applicant's Employer's Phone number"]
            }
        }
      if row["Co-Tenant Employer's Name"].present?
        employment_hash['secondary_applicant'] =
          {
            'address' =>
              {
                'city' => row["Co-Tenant's Employer's Address-City"],
                'state' => row["Co-Tenant's Employer's Address-State"],
                'county' => nil,
                'country' => row["Co-Tenant's Employer's Address-Country"],
                'zip_code' => row["Co-Tenant's Employer's Address-Postal / Zip Code"],
                'street_two' => row["Co-Tenant's Employer's Address-Street Address2"],
                'street_name' => row["Co-Tenant's Employer's Address-Street Address"],
                'street_number' => nil
              },
            'company_name' => row["Co-Tenant Employer's Name"],
            'employment_type' => row['Co-Tenant Employment'],
            'job_description' => row['Co-Tenant Employment Description'],
            'company_phone_number' => row["Co-Tenant's Employer's Phone number"]
          }
      end
      employment_hash
    end

    def policy_users(row)
      policy_users_params = [
        {
          primary: true,
          spouse: false,
          user_attributes: {
            email: row["Applicant's Email address"],
            profile_attributes: {
              first_name: row["Applicant's Name-First"],
              last_name: row["Applicant's Name-Last"],
              job_title: row["Applicant's Employment Description"],
              contact_phone: row["Applicant's Phone number"],
              contact_email: row["Applicant's Email address"],
              birth_date: row["Applicant's Date of birth"]&.to_s,
              gender: row['Gender']&.downcase,
              salutation: row['Salutation']&.downcase
            },
            address_attributes: {
              street_number: '',
              street_name: row['Address-Street Address'],
              street_two: row['Address-Street Address Line 2'],
              city: row['Address-City'],
              state: row['Address-State'],
              country: row['Address-Country'],
              county: '',
              zip_code: row['Address-Postal / Zip Code']
            }
          }
        }
      ]
      if row['Co-Tenant Email address2'].present?
        policy_users_params << {
          primary: false,
          spouse: false,
          user_attributes: {
            email: row['Co-Tenant Email address2'],
            profile_attributes: {
              first_name: row['Co-Tenant Name-First'],
              last_name: row['Co-Tenant Name-Last'],
              job_title: row['Co-Tenant Employment Description'],
              contact_phone: row['Co-Tenant Phone number'],
              contact_email: row['Co-Tenant Email address2'],
              birth_date: row['Co-Tenant Date of birth']&.to_s,
              gender: row['Gender2']&.downcase,
              salutation: row['Co-Tenant Salutation']&.downcase
            },
            address_attributes: {
              street_number: '',
              street_name: row['Address-Street Address'],
              street_two: row['Address-Street Address Line 2'],
              city: row['Address-City'],
              state: row['Address-State'],
              country: row['Address-Country'],
              county: '',
              zip_code: row['Address-Postal / Zip Code']
            }
          }
        }
      end

      policy_users_params
    end

    def row_empty?(row)
      # Excepts always calculated field and strange ending and that doesn't contain primary user's email
      row.except('Program Fee ($)-Dollars').values[0..53].compact.blank? ||
        row["Applicant's Name-First"].blank? ||
        row["Applicant's Email address"].blank?
    end
  end
end
