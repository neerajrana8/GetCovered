module Reports
  module ConsolidatedReports
    class AgencyReportJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform(agency:)
        Reports::ConsolidatedReports::Agency.
          new(reportable: agency, range_start: Time.zone.now - 1.month, range_end: Time.zone.now).
          generate.
          save
      end
    end
  end
end
