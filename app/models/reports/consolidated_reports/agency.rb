module Reports
  module ConsolidatedReports
    class Agency < ::Report
      NAME = 'Consolidated Agency Report'.freeze

      def generate
        completed_applications
        site_visits
        leads_fields
        premium
        quotes
        self
      end

      def column_names
        {
          'address' => 'Address',
          'primary_user' => 'User',
          'policy_type' => 'Policy type',
          'policy' => 'Policy number',
          'contents' => 'Contents',
          'liability' => 'Liability'
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
            },
            'site_visits' => nil,
            'leads' => {
              'count' => nil,
              'average_leads_visits' => nil
            },
            'premium' => {
              'total' => nil,
              'average_lead_premium' => nil,
              'average_policy_premium' => nil
            },
            'quotes' => {
              'quoting_rate' => nil,
              'average_quote_price' => nil,
              'average_time_from_quote_to_conversion' => nil
            }
          }
      end

      # report generation methods (can be moved outside)

      def leads
        @leads ||= Lead.presented.not_archived.where(last_visit: range_start..range_end)
      end

      def leads_fields
        self.data['leads']['count'] = leads.count
        self.data['leads']['average_leads_visits'] = average_leads_visits
        self.data['leads']['average_duration'] = average_duration
      end

      def premium
        total = 0

        Policies.where(id: conversions.pluck('policies.id').uniq).each do |policy|
          total += (policy&.policy_quotes&.last&.policy_premium&.total || 0)
        end

        self.data['premium']['total'] = total
        self.data['premium']['average_lead_premium'] = (total / conversions.pluck('leads.id').uniq.count).round
        self.data['premium']['average_policy_premium'] = (total / conversions.count).round
      end

      def site_visits
        self.data['site_visits'] = @leads.
          lead_events.
          where(created_at: range_start..range_end).
          order('DATE(created_at)').group('DATE(created_at)').
          count.keys.size
      end

      def average_leads_visits
        (self.data['site_visits'] / leads.count).round(2)
      end

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

      def quotes
        quotes_values = leads.map do |lead|
          lead.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.total || last_event&.data['premium_total']
        end.compact

        conversion_time_diff = Policies.where(id: conversions.pluck('policies.id').uniq).map do |policy|
          policy.created_at - policy.policy_quotes&.last&.created_at
        end

        self.data['quotes']['average_quote_price'] = (quotes_values.sum / quotes_values.count).count
        self.data['quotes']['average_time_from_quote_to_conversion'] =
          (conversion_time_diff.sum / 60 / conversion_time_diff.count).round
      end

      def conversions
        @conversions ||= leads.joins(user: :policies).where(policies: { created_at: range_start..range_end })
      end
    end
  end
end
