module PolicyApplicationGroups
  class SourceXlsxParser < ActiveInteraction::Base
    object :xlsx_file, class: IO

    def execute
      xlsx = Roo::Spreadsheet.open(xlsx_file)
      sheet = xlsx.sheet(0).parse(headers: true)
      result = []
      sheet[1..-1].each do |row|
        refined_row = refine_row(row)
        if refined_row.values.compact.blank?
          break
        else
          result << refined_row
        end
      end
      result
    end

    private

    def refine_row(row)
      {
        date: row['Date'],
        applicant_salutation: row['Salutation'],
        applicant_first_name: row["Applicant's Name-First"],
        applicant_last_name: row["Applicant's Name-Last"],
        applicant_birthday: row["Applicant's Date of birth" ],
        applicant_gender: row["Gender"],
        applicant_phone: row["Phone number"],
        applicant_email: row["Applicant's Email address"],
        address_1: row["Address-Street Address"],
        address_2: row["Address-Street Address Line 2"],
        address_city: row["Address-City"],
        address_state: row["Address-State"],
        address_code: row["Address-Postal / Zip Code"],
        address_country: row["Address-State"],
        applicant_employment_type: row["Applicant's Employment type"],
        applicant_employment_description: row["Applicant's Employment Description"],
        applicant_income: row["Applicant's Monthly Income"],
        monthly_rent: row["Monthly Rent ($)-Dollars"],
        guarantee_period: row["3, 6, or 12 Months Option Rent Guarantee"],
        terms_of_payment: row["Terms of Payment"],
        program_fee: row["Monthly Rent ($)-Dollars"].present? ? row["Program Fee ($)-Dollars"] : nil,
        co_tenant_salutation: row["Salutation"],
        co_tenant_first_name: row["Co-Tenant Name-First"],
        co_tenant_last_name: row["Co-Tenant Name-Last"],
        co_tenant_birthday: row["Co-Tenant Date of birth"],
        co_tenant_gender: row["Gender2"],
        co_tenant_phone: row["Co-Tenant Phone number"],
        co_tenant_email: row["Co-Tenant Email address2"],
        co_tenant_employment_type: row["Co-Tenant Employment"],
        co_tenant_employment_description: row["Co-Tenant Employment Description"],
        co_tenant_income: row["Co-Tenant Monthly Income"],
        landlord_company_name: row["Landlord - Company Name (if applicable)"],
        landlord_first_name: row["Landlord Contact name-First"],
        landlord_last_name: row["Landlord Contact name-Last"],
        landlord_phone: row["Landlord Phone number"],
        landlord_email: row["Landlord Email Address" ],
        applicant_employer_name: row["Applicant's Employer's Name"],
        applicant_employer_address_1: row["Applicant's Employer's Address-Street Address" ],
        applicant_employer_address_2: row["Applicant's Employer's Address-Street Address Line 2" ],
        applicant_employer_city: row["Applicant's Employer's Address-City" ],
        applicant_employer_state: row["Applicant's Employer's Address-State"],
        applicant_employer_code: row["Applicant's Employer's Address-Postal / Zip Code"],
        applicant_employer_country: row["Applicant's Employer's Address-Country"],
        applicant_employer_phone: row["Applicant's Employer's Phone number"],
        co_tenant_employer_name: row["Co-Tenant Employer's Name" ],
        co_tenant_employer_address_1: row["Co-Tenant's Employer's Address-Street Address"],
        co_tenant_employer_address_2: row["Co-Tenant's Employer's Address-Street Address2"],
        co_tenant_employer_city: row["Co-Tenant's Employer's Address-City"],
        co_tenant_employer_state: row["Co-Tenant's Employer's Address-State"],
        co_tenant_employer_code: row["Co-Tenant's Employer's Address-Postal / Zip Code"],
        co_tenant_employer_country: row["Co-Tenant's Employer's Address-Country" ],
        co_tenant_employer_phone: row["Co-Tenant's Employer's Phone number"],
        referral_code: row["Referral Code"],
        reference_id: row["Reference ID"]
      }
    end
  end
end
