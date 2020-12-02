module Reports
  class DailyPurchaseActivityJob < ApplicationJob
    queue_as :default

    def perform(target_date: nil)

      report_date = target_date.nil? ? (Time.now - 1.days) : target_date
      trash_can = []
      @agencies = Agency.all

      @agencies.each do |agency|

        report = Reports::DailyPurchaseActivity.new(range_start: report_date.beginning_of_day,
                                                    range_end: report_date.end_of_day,
                                                    reportable: agency)
        report.generate
        if report.save
          if report.data["rows"].count > 0
            file_path = report.generate_csv
            StaffReportsMailer.with(notifiable: agency.owner, report_path: file_path).daily_purchase_activity.deliver
            trash_can << file_path
          end
        else
          logger.debug report.errors
        end
      end

      trash_can.each { |trash| File.delete(trash) if File.exist?(trash) }

    end
  end
end
