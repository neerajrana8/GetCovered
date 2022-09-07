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
    class ExpireSoonPolicies < ::Report
      NAME = 'Detailed Renters Insurance - Expire soon policies'.freeze

      def generate
        units =
          if reportable.is_a?(Insurable)
            reportable.units
          else
            reportable.insurables.units
          end
        units&.each do |unit|
          policy = unit.policies.take
          if (policy&.auto_renew == false) && (policy&.expiration_date < Time.current + 30.days)
            self.data['rows'] << {
              'address' => unit.title,
              'primary_user' => policy.primary_user&.profile&.full_name,
              'policy_type' => 'H04',
              'policy' => policy.number,
              'expiration_date' => policy.expiration_date
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
          'expiration_date' => 'Expiration date'
        }
      end

      def headers
        %w[address primary_user policy_type policy expiration_date]
      end

      private

      def set_defaults
        self.data ||= { rows:[] }
      end
    end
  end
end
