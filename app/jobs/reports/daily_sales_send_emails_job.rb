module Reports
  class DailySalesSendEmailsJob < ApplicationJob
    queue_as :default

    def perform
      range_start = Time.zone.now
      report_path = Reports::DailySalesAggregate.new(range_start: range_start).generate_csv
      recipients = Agency.get_covered.staff.pluck(:email)
      DailySalesReportMailer.send_report(recipients, report_path, 'All partners', range_start.to_date.to_s)
    end
  end
end
