module Reports
  class WeeklyConsolidatedReportsJob < ApplicationJob
    queue_as :default

    def perform
      reports = agencies_reports
      getcovered_aggregate_report(reports)
    end

    private

    def getcovered_aggregate_report(agencies_reports)
      report = Reports::ConsolidatedReports::Aggregate.new(
        reportable: Agency.get_covered,
        range_start: Time.zone.now - 7.days,
        range_end: Time.zone.now
      ).generate(agencies_reports)
    end

    def agencies_reports
      reports = Agency.all.map do |agency|
        Reports::ConsolidatedReports::Agency.new(
          reportable: agency,
          range_start: Time.zone.now - 7.days,
          range_end: Time.zone.now
        ).generate
      end

      reports.each do |report|
        Reports::ConsolidatedReportsMailer.agency_report(report: report).deliver
      end

      reports
    end
  end
end
