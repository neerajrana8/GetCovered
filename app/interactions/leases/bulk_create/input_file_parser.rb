module Leases
  module BulkCreate
    class InputFileParser < ActiveInteraction::Base
      file :input_file
      integer :insurable_id, default: nil
      
      # WARNING: no support for Lease#end_date being nil

      HEADERS = %w[start_date end_date status lease_type unit
                   tenant_one_email tenant_one_first_name tenant_one_last_name tenant_one_birthday
                   tenant_two_email tenant_two_first_name tenant_two_last_name tenant_two_birthday].freeze
      ALWAYS_PRESENT_ROWS = %w[start_date end_date status lease_type unit
                               tenant_one_email tenant_one_first_name tenant_one_last_name tenant_one_birthday].freeze
      VALID_LEASE_TYPES = %w[Residential Commercial].freeze
      DATE_FORMAT = '%m/%d/%Y'.freeze

      def execute
        result = []
        parsed_file.each_with_index do |row, index|
          next unless row_valid?(row, index + 2)

          refined_row = refine_row(row, index + 2)
          next unless refined_row

          result << params(refined_row)
        end
        result
      end

      private

      def row_valid?(row, row_number)
        empty_necessary_rows = ALWAYS_PRESENT_ROWS.select { |column| row[column].blank? }
        if empty_necessary_rows.any?
          errors[:bad_rows] << {
            message: "Next columns in the row #{row_number} should be present: #{empty_necessary_rows.join(', ')}",
            row: row_number
          }
          return false
        end

        unless tenant_data_valid?(row, row_number, 'one')
          return false
        end

        if row['tenant_two_email'].present? && !tenant_data_valid?(row, row_number, 'two')
          return false
        end

        unless VALID_LEASE_TYPES.include?(row['lease_type'])
          errors[:bad_rows] << {
            message: "Row #{row_number} has the incorrect lease_type",
            row: row_number
          }
          return false
        end

        unless Lease.statuses.keys.include?(row['status'])
          errors[:bad_rows] << {
            message: "Row #{row_number} has the incorrect status",
            row: row_number
          }
          return false
        end

        if parse_date(row['start_date']) > parse_date(row['end_date'])
          errors[:bad_rows] << {
            message: "In the Row #{row_number} end_date is earlier than start_date",
            row: row_number
          }
          return false
        end

        true
      rescue ArgumentError => _e
        errors[:bad_rows] << {
          message: "Row #{row_number} contains invalid date",
          row: row_number
        }

        return false
      end

      def tenant_data_valid?(row, row_number, tenant)
        if row["tenant_#{tenant}_birthday"].blank? || parse_date(row["tenant_#{tenant}_birthday"]) > 18.years.ago
          errors[:bad_rows] << {
            message: "Tenant #{tenant} in the row #{row_number} should be older than 18",
            row: row_number
          }
          return
        end

        empty_tenant_rows = %W[tenant_#{tenant}_first_name tenant_#{tenant}_last_name].select do |column|
          row[column].blank?
        end

        if empty_tenant_rows.any?
          errors[:bad_rows] << {
            message: "Next columns in the row #{row_number} should be present: #{empty_tenant_rows.join(', ')}",
            row: row_number
          }
          return false
        end

        true
      end

      def parse_date(date_string)
        Date.strptime(date_string, DATE_FORMAT)
      end

      def refine_row(row, row_number)
        unit_id = Insurable.where(
          insurable_id: insurable_id,
          title: row['unit'],
          insurable_type_id: InsurableType::RESIDENTIAL_UNITS_IDS
        ).take&.id
        if unit_id.present?
          row['insurable_id'] = unit_id
        else
          errors[:bad_rows] << {
            message: "Unit #{row['unit']} in the row #{row_number} doesn't exist in the system",
            row: row_number
          }
          return false
        end

        row['lease_type'] = LeaseType.find_by_title(row['lease_type'])
        row['start_date'] = parse_date(row['start_date'])
        row['end_date'] =   parse_date(row['end_date'])
        row
      end

      def params(refined_row)
        {
          lease: {
            start_date: refined_row['start_date'],
            end_date: refined_row['end_date'],
            status: refined_row['status'],
            lease_type: refined_row['lease_type'],
            insurable_id: refined_row['insurable_id']
          },
          lease_users: lease_users_params(refined_row)
        }
      end

      def lease_users_params(row)
        lease_users = [
          {
            primary: true,
            user_attributes: {
              email: row['tenant_one_email'],
              profile_attributes: {
                first_name: row['tenant_one_first_name'],
                last_name: row['tenant_one_last_name'],
                birth_date: parse_date(row['tenant_one_birthday']),
                contact_email: row['tenant_one_email']
              }
            }
          }
        ]

        if row['tenant_two_email'].present?
          lease_users << {
            primary: true,
            user_attributes: {
              email: row['tenant_two_email'],
              profile_attributes: {
                first_name: row['tenant_two_first_name'],
                last_name: row['tenant_two_last_name'],
                birth_date: parse_date(row['tenant_two_birthday']),
                contact_email: row['tenant_two_email']
              }
            }
          }
        end
        lease_users
      end

      def parsed_file
        @parsed_file ||= CSV.parse(input_file, headers: true)
      end
    end
  end
end
