module Leases
  module BulkCreate
    class InputFileParser < ActiveInteraction::Base
      file :input_file
      

      HEADERS = %w[start_date end_date status lease_type unit
                   tenant_one_email tenant_one_first_name tenant_one_last_name tenant_one_birthday
                   tenant_two_email tenant_two_first_name tenant_two_last_name tenant_two_birthday].freeze
      ALWAYS_PRESENT_ROWS = %w[start_date end_date status lease_type unit].freeze
      VALID_LEASE_TYPES = %w[Residential Commercial].freeze
      DATE_FORMAT = '%m/%d/%Y'.freeze

      def execute
        result = []
        parsed_file.each_with_index do |row, index|
          next unless row_valid?(row, index + 2)

          result << params(row)
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

        if row['tenant_one_email'].present? && (row['tenant_one_email'].blank? || row['tenant_one_email'] > 18.years.ago)
          errors[:bad_rows] << {
            message: "Row #{row_number} has the incorrect of birth",
            row: row_number
          }
          return
        end

        if row['tenant_two_email'].present? && (row['tenant_two_email'].blank? || row['tenant_two_email'] > 18.years.ago)
          errors[:bad_rows] << {
            message: "Row #{row_number} has the incorrect of birth",
            row: row_number
          }
          return
        end

        unless VALID_LEASE_TYPES.include?(row['lease_type'])
          errors[:bad_rows] << {
            message: "Row #{row_number} has the incorrect lease_type",
            row: row_number
          }
          return
        end

        unless Lease.statuses.keys.include?(row['status'])
          errors[:bad_rows] << {
            message: "Row #{row_number} has the incorrect status",
            row: row_number
          }
          return
        end

        begin
          if Date.strptime(row['start_date'], DATE_FORMAT) > Date.strptime(row['end_date'], DATE_FORMAT)
            errors[:bad_rows] << {
              message: "In the Row #{row_number} end_date is earlier than start_date",
              row: row_number
            }
            return
          end
        rescue ArgumentError => _e
          errors[:bad_rows] << {
            message: "Row #{row_number} has invalid end start_date or end_date",
            row: row_number
          }
          return
        end

        true
      end

      def params(refined_row)
        {
          lease: {
            start_date: refined_row['start_date'],
            end_date: refined_row['end_date'],
            status: refined_row['status'],
            lease_type: refined_row['lease_type'],
            insurable: refined_row['insurable_id']
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
                birth_date: row['tenant_one_birthday']&.to_s,
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
                birth_date: row['tenant_two_birthday']&.to_s,
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
