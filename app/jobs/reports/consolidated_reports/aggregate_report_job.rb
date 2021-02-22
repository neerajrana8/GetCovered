module Reports
  module ConsolidatedReports
    class AggregateReportJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform
        Reports::ConsolidatedReports::Aggregate.
          new(reportable: ::Agency.get_covered, range_start: Time.zone.now - 1.month, range_end: Time.zone.now).
          generate.
          save
      end
    end
  end
end
