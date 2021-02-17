module Reports
  module ConsolidatedReports
    class Agency < ::Report
      NAME = 'Consolidated Agency Report'.freeze

      def generate
        by_products
        aggregate if leads.count.positive?

        self
      end

      def headers
        %w[address primary_user policy_type policy contents liability]
      end

      private

      def set_defaults
        self.data ||= {
          'aggregate' => {
            'completed_applications' => {
              'average_time_minutes' => 0,
              'conversion_rate' => 0
            },
            'site_visits' => 0,
            'leads' => {
              'count' => 0,
              'average_leads_visits' => 0
            },
            'premium' => {
              'total' => 0,
              'average_lead_premium' => 0,
              'average_policy_premium' => 0
            },
            'quotes' => {
              'average_quote_price' => 0,
              'average_time_from_quote_to_conversion' => 0
            }
          },
          'by_products' => {}
        }
      end

      # report generation methods (can be moved outside)

      def aggregate
        self.data['aggregate'] = report(leads, policy_applications)
      end

      def by_products
        result =
          PolicyType.all.map do |policy_type|
            next if leads_for_product(policy_type.id).count.zero?

            {
              'policy_type_id' => policy_type.id,
              'report' => report(leads_for_product(policy_type.id), policy_applications(policy_type.id))
            }
          end.compact
        self.data['by_products'] = result
      end

      def report(leads, policy_applications)
        conversions = conversions(leads)

        visits = leads.
          joins(:lead_events).
          where(lead_events: { created_at: range_start..range_end }).
          order('DATE(lead_events.created_at)').group('DATE(lead_events.created_at)').
          count.keys.size

        time_diffs =
          policy_applications.joins(:policy).
            pluck('policy_applications.created_at', 'policies.created_at').
            map { |d1, d2| (d2 - d1) }

        premium_total = 0

        Policy.where(id: conversions.pluck('policies.id').uniq).each do |policy|
          premium_total += (policy&.policy_quotes&.last&.policy_premium&.total || 0)
        end

        quotes_values = leads.map do |lead|
          lead.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.total || lead.last_event&.data['premium_total']
        end.compact

        conversion_time_diff = Policy.where(id: conversions.pluck('policies.id').uniq).map do |policy|
          policy.created_at - policy.policy_quotes&.last&.created_at
        end

        average_lead_premium = conversions.count > 0 ? (premium_total / conversions.pluck('leads.id').uniq.count).round : 0
        average_policy_premium = conversions.count > 0 ? (premium_total / conversions.count).round : 0

        average_quote_price = quotes_values.count > 0 ? (quotes_values.sum / quotes_values.count) : 0
        average_time_from_quote_to_conversion =
          conversion_time_diff.count > 0 ? (conversion_time_diff.sum / 60 / conversion_time_diff.count).round : 0

        {
          'site_visits' => visits,
          'completed_applications' => {
            'average_time_minutes' => time_diffs.count.positive? ? (time_diffs.sum / 60 / time_diffs.count).round : 0,
            'conversion_rate' => policy_applications.count.positive? ? conversions.count / policy_applications.count : 0
          },
          'leads' => {
            'count' => leads.count,
            'average_leads_visits' => (visits.to_f / leads.count).round(2)
          },
          'premium' => {
            'total' => premium_total,
            'average_lead_premium' => average_lead_premium,
            'average_policy_premium' => average_policy_premium
          },
          'quotes' => {
            'average_quote_price' => average_quote_price,
            'average_time_from_quote_to_conversion' => average_time_from_quote_to_conversion
          }
        }
      end

      def leads
        Lead.presented.not_archived.where(last_visit: range_start..range_end)
      end

      def leads_for_product(policy_type_id)
        Lead.presented.not_archived.
          where(last_visit: range_start..range_end).
          joins(:lead_events).
          where(lead_events: { policy_type_id: policy_type_id }).
          distinct
      end

      def leads_fields
        self.data['leads']['count'] = leads.count
        self.data['leads']['average_leads_visits'] = average_leads_visits(leads)
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

      def average_leads_visits(leads)
        (self.data['site_visits'] / leads.count).round
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

      def policy_applications(policy_type_id = nil)
        query =
          reportable.
            policy_applications.
            where(created_at: range_start..range_end)

        query = query.where(policy_type_id: policy_type_id) if policy_type_id.present?

        query
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

      def conversions(leads)
        leads.joins(user: :policies).where(policies: { created_at: range_start..range_end })
      end
    end
  end
end
