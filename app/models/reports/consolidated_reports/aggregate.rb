module Reports
  module ConsolidatedReports
    class Aggregate < ::Reports::ConsolidatedReports::Base
      NAME = 'Consolidated Aggregated Report'.freeze

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
    end
  end
end
