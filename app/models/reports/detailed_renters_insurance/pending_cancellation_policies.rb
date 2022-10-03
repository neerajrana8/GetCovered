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
    class PendingCancellationPolicies < ::Report
      NAME = 'Detailed Renters Insurance - Pending cancellation'.freeze

      def generate
        units =
          if reportable.is_a?(Insurable)
            reportable.units&.select{|unit| unit.covered}
          else
            reportable.insurables.units.covered
          end

        units&.each do |insurable|
          policy = insurable.policies.take

          if policy.present? && policy.billing_status == 'BEHIND'
            self.data['rows'] << {
              'address' => insurable.title,
              'primary_user' => policy.primary_user&.profile&.full_name,
              'policy_type' => 'H04',
              'policy' => policy.number,
              'cancel_reason' => 'Behind billing',
              'pending_cancel_date' => policy
            }
          end
        end
        self
      end

      def column_names
        {
          'address' => 'Address',
          'primary_user' => 'User',
          'policy_type' => 'Policy type',
          'policy' => 'Policy number',
          'cancel_reason' => 'Cancel reason',
          'pending_cancel_date' => 'Cancel date',
        }
      end

      def headers
        %w[address primary_user policy_type policy cancel_reason pending_cancel_date]
      end

      private

      def set_defaults
        self.data ||= { rows: [] }
      end
    end
  end
end
