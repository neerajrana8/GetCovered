module Reports
  module ConsolidatedReports
    class Agency < ::Report
      NAME = 'Consolidated Agency Report'.freeze

      def generate
        completed_applications

        self
      end

      def column_names
        {
          'address' => 'Address',
          'primary_user' => 'User',
          'policy_type' => 'Policy type',
          'policy' => 'Policy number',
          'contents' => 'Contents',
          'liability' => 'Liability',
        }
      end

      def headers
        %w[address primary_user policy_type policy contents liability]
      end

      private

      def set_defaults
        self.data ||=
          {
            'completed_applications' => {
              'average_time_minutes' => nil,
              'conversion_rate' => nil
            }
          }
      end

      # report generation methods (can be moved outside)

      def completed_applications
        time_diffs =
          policy_applications.joins(:policy).
            pluck('policy_applications.created_at', 'policies.created_at').
            map { |d1, d2| (d2 - d1) }

        self.data['completed_applications']['average_time_minutes'] = (time_diffs.sum / 60 / time_diffs.count).round
        self.data['completed_applications']['conversion_rate'] = conversion_rate
      end

      def conversion_rate
        conversions.count / policy_applications.count
      end

      def policy_applications
        reportable.
          policy_applications.
          where(created_at: range_start..range_end)
      end

      def conversions
        @conversions ||= Lead.
          presented.
          not_archived.
          where(last_visit: range_start..range_end).
          joins(user: :policies).
          where(policies: { created_at: range_start..range_end })
      end
    end
  end
end
