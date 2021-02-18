module Reports
  module ConsolidatedReports
    class Agency < ::Reports::ConsolidatedReports::Base
      NAME = 'Consolidated Agency Report'.freeze

      def leads
        Lead.presented.not_archived.where(last_visit: range_start..range_end, agency_id: reportable.id)
      end

      def leads_for_product(policy_type_id)
        Lead.presented.not_archived.
          where(last_visit: range_start..range_end, agency_id: reportable.id).
          joins(:lead_events).
          where(lead_events: { policy_type_id: policy_type_id }).
          distinct
      end
    end
  end
end
