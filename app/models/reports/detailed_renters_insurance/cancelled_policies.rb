# == Schema Information
#
# Table name: reports
#
#  id              :bigint           not null, primary key
#  duration        :integer
#  range_start     :datetime
#  range_end       :datetime
#  data            :jsonb
#  reportable_type :string
#  reportable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  type            :string
#
module Reports
  module DetailedRentersInsurance
    class CancelledPolicies < ::Report
      NAME = 'Detailed Renters Insurance - Cancelled policies'.freeze

      def generate
        units =
          if reportable.is_a?(Insurable)
            reportable.units
          else
            reportable.insurables.units
          end

        units&.each do |unit|
          policy = unit.policies.take
          if policy&.status == 'CANCELLED'
            self.data['rows'] << {
              'address' => unit.title,
              'primary_user' => policy.primary_user&.profile&.full_name,
              'policy_type' => 'H04',
              'policy' => policy.number,
              'cancel_reason' => 'Non Payment',
              'cancel_date' => policy.cancellation_date
            }
          end
        end
        self
      end

      private

      def set_defaults
        self.data ||= { rows: [] }
      end

      def column_names
        {
          'address' => 'Address',
          'primary_user' => 'User',
          'policy_type' => 'Policy type',
          'policy' => 'Policy number',
          'cancel_reason' => 'Cancel reason',
          'cancel_date' => 'Cancel date',
        }
      end

      def headers
        %w[address primary_user policy_type policy cancel_reason cancel_date]
      end
    end
  end
end
