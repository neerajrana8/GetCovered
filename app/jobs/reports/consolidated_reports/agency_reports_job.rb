module Reports
  module ConsolidatedReports
    class AgencyReportsJob < ApplicationJob
      # Queue: Default
      queue_as :default

      def perform
        ::Agency.all.each do |agency|
          Reports::ConsolidatedReports::AgencyReportJob.perform_later(agency: agency)
        end
      end
    end
  end
end
