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
          date: row['Date'],
          monthly_rent: row["Monthly Rent ($)-Dollars"],
          guarantee_period: row["3, 6, or 12 Months Option Rent Guarantee"],
          terms_of_payment: row["Terms of Payment"],
          program_fee: row["Monthly Rent ($)-Dollars"].present? ? row["Program Fee ($)-Dollars"] : nil,
          referral_code: row["Referral Code"],
          reference_id: row["Reference ID"]
        },
        property_address: {
          address_1: row["Address-Street Address"],
          address_2: row["Address-Street Address Line 2"],
          address_city: row["Address-City"],
          address_state: row["Address-State"],
          address_code: row["Address-Postal / Zip Code"],
        },
        applicant: {
          salutation: row['Salutation'],
          first_name: row["Applicant's Name-First"],
          last_name: row["Applicant's Name-Last"],
          birthday: row["Applicant's Date of birth" ],
          gender: row["Gender"],
          phone: row["Phone number"],
          email: row["Applicant's Email address"],
          employment_type: row["Applicant's Employment type"],
          employment_description: row["Applicant's Employment Description"],
          income: row["Applicant's Monthly Income"],
          employer: {
            name: row["Applicant's Employer's Name"],
            address_1: row["Applicant's Employer's Address-Street Address" ],
            address_2: row["Applicant's Employer's Address-Street Address Line 2" ],
            city: row["Applicant's Employer's Address-City" ],
            state: row["Applicant's Employer's Address-State"],
            code: row["Applicant's Employer's Address-Postal / Zip Code"],
            country: row["Applicant's Employer's Address-Country"],
            phone: row["Applicant's Employer's Phone number"],
          }
        },
        co_tenant: {
          salutation: row["Salutation"],
          first_name: row["Co-Tenant Name-First"],
          last_name: row["Co-Tenant Name-Last"],
          birthday: row["Co-Tenant Date of birth"],
          gender: row["Gender2"],
          phone: row["Co-Tenant Phone number"],
          email: row["Co-Tenant Email address2"],
          employment_type: row["Co-Tenant Employment"],
          employment_description: row["Co-Tenant Employment Description"],
          income: row["Co-Tenant Monthly Income"],
          employer: {
            name: row["Co-Tenant Employer's Name" ],
            address_1: row["Co-Tenant's Employer's Address-Street Address"],
            address_2: row["Co-Tenant's Employer's Address-Street Address2"],
            city: row["Co-Tenant's Employer's Address-City"],
            state: row["Co-Tenant's Employer's Address-State"],
            code: row["Co-Tenant's Employer's Address-Postal / Zip Code"],
            country: row["Co-Tenant's Employer's Address-Country" ],
            phone: row["Co-Tenant's Employer's Phone number"],
          }
        },
        landlord: {
          first_name: row["Landlord Contact name-First"],
          last_name: row["Landlord Contact name-Last"],
          phone: row["Landlord Phone number"],
          email: row["Landlord Email Address" ],
        }
      }
    end

    def row_empty?(row)
      data = grouped_data(row)
      [
        data[:policy_application],
        data[:property_address],
        data[:landlord],
        data[:applicant].except(:employer),
        data[:co_tenant].except(:employer),
        data.dig(:applicant, :employer),
        data.dig(:co_tenant, :employer)
      ].map(&:values).flatten.compact.blank?
    end
  end
end
