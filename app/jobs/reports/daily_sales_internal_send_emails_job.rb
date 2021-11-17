module Reports
  class DailySalesInternalSendEmailsJob < ApplicationJob
    queue_as :default

    def perform
      range_start = Time.zone.now.in_time_zone('Eastern Time (US & Canada)')
      report_path = Reports::DailySalesAggregate.new(range_start: range_start).generate.generate_csv
      recipients = 
        if Rails.env == 'production'
          ['salesreports@getcovered.io']
        else
          []
        end
      DailySalesReportMailer.send_report(recipients, report_path, 'All partners', range_start.yesterday.to_date.to_s).deliver
    end
  end
end
